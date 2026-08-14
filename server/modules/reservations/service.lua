-- Persistent public Field reservations and co-op membership.

Reservations = Reservations or {}

local function encode(value) return json.encode(value or {}) end
local function now() return Sonar.Time.Now() end
local function rows(query, values) return MySQL.query.await(query, values) or {} end

local function liveCrops(reservationId, owner)
    local count = 0
    for _, crop in pairs(State.crops or {}) do
        local data = crop.data or {}
        if data.reservationId == reservationId and (not owner or crop.owner == owner) then count = count + 1 end
    end
    return count
end

local function distance(left, right)
    if not left or not right then return math.huge end
    local dx, dy, dz = left.x - right.x, left.y - right.y, left.z - right.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return nil end
    local coords = GetEntityCoords(ped)
    return coords and { x = coords.x, y = coords.y, z = coords.z } or nil
end

local function price(sizeClass, hours, level, grace)
    local base = Config.Reservations.Prices[sizeClass] and Config.Reservations.Prices[sizeClass][hours]
    if not base then return nil end
    local perks = Progression.Perks(level)
    local discounted = math.floor(base * (1 - perks.rentDiscount) + 0.5)
    return grace and math.floor(discounted * (1 + Config.Reservations.GraceSurcharge) + 0.5) or discounted, base
end

function Reservations.PricePlans(sizeClass, level, grace)
    local output = {}
    for _, hours in ipairs({ 6, 12, 24 }) do
        local paid, base = price(sizeClass, hours, level, grace)
        output[#output + 1] = { hours = hours, basePrice = base, price = paid, graceSurcharge = grace == true }
    end
    return output
end

function Reservations.GetLink(identifier)
    return identifier and MySQL.single.await([[SELECT l.*,m.role,m.status,r.field_id,r.owner_identifier,
        r.status reservation_status,r.expires_at,r.grace_until FROM sfpj_player_links l
        JOIN sfpj_reservation_members m ON m.reservation_id=l.reservation_id AND m.identifier=l.identifier
        JOIN sfpj_reservations r ON r.id=l.reservation_id WHERE l.identifier=?]], { identifier }) or nil
end

function Reservations.GetByField(fieldId)
    return MySQL.single.await([[SELECT r.* FROM sfpj_field_claims c JOIN sfpj_reservations r ON r.id=c.reservation_id
        WHERE c.field_id=? AND r.status IN ('active','grace')]], { fieldId })
end

function Reservations.GetForPlayer(identifier)
    local link = Reservations.GetLink(identifier)
    return link and Reservations.Snapshot(link.reservation_id, identifier) or nil
end

function Reservations.Snapshot(reservationId, viewer)
    local reservation = MySQL.single.await('SELECT * FROM sfpj_reservations WHERE id=?', { reservationId })
    if not reservation then return nil end
    local members = rows([[SELECT identifier,display_name,role,status,joined_at,left_at
        FROM sfpj_reservation_members WHERE reservation_id=? ORDER BY role DESC,joined_at]], { reservationId })
    local own = 0
    if viewer then own = liveCrops(reservationId, viewer) end
    return { id = reservation.id, fieldId = reservation.field_id, role = viewer == reservation.owner_identifier and 'owner' or 'guest',
        status = reservation.status, expiresAt = tonumber(reservation.expires_at), graceUntil = tonumber(reservation.grace_until),
        planHours = tonumber(reservation.plan_hours), paidPrice = tonumber(reservation.paid_price),
        members = members, liveCrops = liveCrops(reservationId), ownCrops = own,
        isOwner = viewer == reservation.owner_identifier }
end

local function operation(operationId, identifier, kind, status, amount, payload)
    return MySQL.update.await([[INSERT INTO sfpj_economy_operations (id,identifier,kind,status,amount,payload)
        VALUES (?,?,?,?,?,?) ON DUPLICATE KEY UPDATE id=id]],
        { operationId, identifier, kind, status, amount, encode(payload) })
end

local function compensate(identifier, amount, operationId, reason)
    if Bridge.CreditMoney(identifier, 'bank', amount, reason, operationId .. ':refund') then
        MySQL.update.await("UPDATE sfpj_economy_operations SET status='compensated',last_error=? WHERE id=?",
            { reason, operationId })
    else
        MySQL.transaction.await({
            { query = "UPDATE sfpj_economy_operations SET status='compensation_pending',last_error=? WHERE id=?",
              values = { reason, operationId } },
            { query = [[INSERT IGNORE INTO sfpj_economy_outbox (id,operation_id,action,status,payload)
                VALUES (?,?,'bank_credit','pending',?)]],
              values = { Sonar.Utils.Uuid(), operationId, encode({ identifier = identifier, amount = amount, reason = reason }) } },
        })
    end
end

function Reservations.Reserve(source, fieldId, hours, operationId)
    local actor, reason = PublicJob.Guard(source)
    if not actor then
        Logger.Warn(('Reserve failed: PublicJob.Guard rejected (reason=%s)'):format(tostring(reason)), 'reservations')
        return { ok = false, reason = reason }
    end
    local field = Fields.Get(tostring(fieldId or ''))
    hours = tonumber(hours)
    operationId = tostring(operationId or Sonar.Utils.Uuid())
    if not field or (not field.catalogVisible and not Config.Debug) then
        Logger.Warn(('Reserve failed: field_not_found (fieldId=%s, catalogVisible=%s)'):format(tostring(fieldId), tostring(field and field.catalogVisible)), 'reservations')
        return { ok = false, reason = 'field_not_found' }
    end
    if not Config.Reservations.Plans[hours] then
        Logger.Warn(('Reserve failed: invalid_plan (hours=%s)'):format(tostring(hours)), 'reservations')
        return { ok = false, reason = 'invalid_plan' }
    end
    local permitted, required, progress = Progression.CanReserveSize(actor.identifier, field.sizeClass)
    if not permitted then
        Logger.Warn(('Reserve failed: level_required (requiredLevel=%s, currentLevel=%s)'):format(tostring(required), tostring(progress and progress.level)), 'reservations')
        return { ok = false, reason = 'level_required', requiredLevel = required }
    end

    local acquired, result = Lock.With('reservation:player:' .. actor.identifier, function()
        if Reservations.GetLink(actor.identifier) then
            Logger.Warn(('Reserve failed: already_participating (%s)'):format(actor.identifier), 'reservations')
            return { ok = false, reason = 'already_participating' }
        end
        if tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sfpj_cooldowns WHERE identifier=? AND field_id=? AND expires_at>?]],
            { actor.identifier, field.id, now() })) > 0 then
            Logger.Warn(('Reserve failed: field_cooldown (%s on %s)'):format(actor.identifier, field.id), 'reservations')
            return { ok = false, reason = 'field_cooldown' }
        end
        if Reservations.GetByField(field.id) then
            Logger.Warn(('Reserve failed: field_unavailable (%s)'):format(field.id), 'reservations')
            return { ok = false, reason = 'field_unavailable' }
        end
        local paid, base = price(field.sizeClass, hours, progress.level, false)
        local replay = MySQL.single.await("SELECT status FROM sfpj_economy_operations WHERE id=? AND identifier=? AND kind='reservation'",
            { operationId, actor.identifier })
        if replay then return { ok = PublicJobEconomy.IsFulfilled(replay.status), reason = replay.status, replay = true } end
        if tonumber(operation(operationId, actor.identifier, 'reservation', 'prepared', paid,
            { fieldId = field.id, hours = hours })) ~= 1 then return { ok = false, reason = 'operation_conflict' } end
        if not Bridge.DebitMoney(source, 'bank', paid, 'Public field reservation', operationId) then
            MySQL.update.await("UPDATE sfpj_economy_operations SET status='failed',last_error='insufficient_funds' WHERE id=?", { operationId })
            return { ok = false, reason = 'insufficient_funds' }
        end
        local reservationId, timestamp = Sonar.Utils.Uuid(), now()
        local committed = MySQL.transaction.await({
            { query = [[INSERT INTO sfpj_reservations
                (id,field_id,owner_identifier,status,plan_hours,base_price,paid_price,started_at,expires_at)
                VALUES (?,?,?,'active',?,?,?,?,?)]],
              values = { reservationId, field.id, actor.identifier, hours, base, paid, timestamp,
                  timestamp + Config.Reservations.Plans[hours] } },
            { query = 'INSERT INTO sfpj_field_claims (field_id,reservation_id) VALUES (?,?)', values = { field.id, reservationId } },
            { query = [[INSERT INTO sfpj_reservation_members
                (reservation_id,identifier,display_name,role,status,joined_at) VALUES (?,?,?,'owner','active',?)]],
              values = { reservationId, actor.identifier, actor.name, timestamp } },
            { query = "INSERT INTO sfpj_player_links (identifier,reservation_id,member_status) VALUES (?,?,'active')",
              values = { actor.identifier, reservationId } },
            { query = "UPDATE sfpj_economy_operations SET status='committed',payload=? WHERE id=?",
              values = { encode({ reservationId = reservationId, fieldId = field.id }), operationId } },
        })
        if not committed then
            compensate(actor.identifier, paid, operationId, 'reservation_commit_failed')
            return { ok = false, reason = 'field_unavailable' }
        end
        PublicJobEconomy.Finalize(operationId)
        Fields.BroadcastInvalidate(field.id, 'reserved')
        return { ok = true, reservation = Reservations.Snapshot(reservationId, actor.identifier) }
    end)
    return acquired and result or { ok = false, reason = 'operation_in_progress' }
end

function Reservations.Extend(source, hours, operationId)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    hours, operationId = tonumber(hours), tostring(operationId or Sonar.Utils.Uuid())
    if not Config.Reservations.Plans[hours] then return { ok = false, reason = 'invalid_plan' } end
    local acquired, result = Lock.With('reservation:player:' .. actor.identifier, function()
        local link = Reservations.GetLink(actor.identifier)
        if not link or link.role ~= 'owner' then return { ok = false, reason = 'owner_required' } end
        local reservation = MySQL.single.await('SELECT * FROM sfpj_reservations WHERE id=?', { link.reservation_id })
        if not reservation or (reservation.status ~= 'active' and reservation.status ~= 'grace') then
            return { ok = false, reason = 'reservation_inactive' }
        end
        local timestamp = now()
        local currentExpiry = math.max(timestamp, tonumber(reservation.expires_at) or timestamp)
        local newExpiry = currentExpiry + Config.Reservations.Plans[hours]
        if newExpiry > timestamp + Config.Reservations.MaximumRemainingSeconds then
            return { ok = false, reason = 'maximum_expiry' }
        end
        local field, progress = Fields.Get(reservation.field_id), Progression.Get(actor.identifier)
        local paid = price(field.sizeClass, hours, progress.level, reservation.status == 'grace')
        local replay = MySQL.single.await("SELECT status FROM sfpj_economy_operations WHERE id=? AND identifier=? AND kind='extension'",
            { operationId, actor.identifier })
        if replay then return { ok = PublicJobEconomy.IsFulfilled(replay.status), reason = replay.status, replay = true } end
        if tonumber(operation(operationId, actor.identifier, 'extension', 'prepared', paid,
            { reservationId = reservation.id, hours = hours })) ~= 1 then return { ok = false, reason = 'operation_conflict' } end
        if not Bridge.DebitMoney(source, 'bank', paid, 'Public field extension', operationId) then
            MySQL.update.await("UPDATE sfpj_economy_operations SET status='failed',last_error='insufficient_funds' WHERE id=?", { operationId })
            return { ok = false, reason = 'insufficient_funds' }
        end
        local changed = MySQL.transaction.await({
            { query = [[UPDATE sfpj_reservations SET status='active',expires_at=?,grace_until=NULL,
                plan_hours=?,paid_price=paid_price+? WHERE id=? AND status IN ('active','grace')]],
              values = { newExpiry, hours, paid, reservation.id } },
            { query = "UPDATE sfpj_economy_operations SET status='committed',payload=? WHERE id=?",
              values = { encode({ reservationId = reservation.id, expiresAt = newExpiry }), operationId } },
        })
        if changed ~= true then
            compensate(actor.identifier, paid, operationId, 'extension_commit_failed')
            return { ok = false, reason = 'reservation_changed' }
        end
        PublicJobEconomy.Finalize(operationId)
        Fields.BroadcastInvalidate(reservation.field_id, 'extended')
        return { ok = true, reservation = Reservations.Snapshot(reservation.id, actor.identifier) }
    end)
    return acquired and result or { ok = false, reason = 'operation_in_progress' }
end

local function releaseMember(reservationId, identifier, status)
    MySQL.transaction.await({
        { query = 'UPDATE sfpj_reservation_members SET status=?,left_at=? WHERE reservation_id=? AND identifier=?',
          values = { status, now(), reservationId, identifier } },
        { query = 'DELETE FROM sfpj_player_links WHERE identifier=? AND reservation_id=?', values = { identifier, reservationId } },
    })
end

function Reservations.Purge(reservationId, reason)
    local reservation = MySQL.single.await('SELECT * FROM sfpj_reservations WHERE id=?', { reservationId })
    if not reservation or reservation.status == 'released' then return false end
    local removed = {}
    for id, crop in pairs(State.crops or {}) do
        if crop.data and crop.data.reservationId == reservationId then removed[#removed + 1] = { id = id, cell = crop.cell } end
    end
    local timestamp, cooldown = now(), now() + Config.Reservations.SameFieldCooldownSeconds
    local queries = {
        { query = [[INSERT INTO sfpj_cooldowns (identifier,field_id,expires_at)
            SELECT identifier,?,? FROM sfpj_reservation_members WHERE reservation_id=?
            ON DUPLICATE KEY UPDATE expires_at=GREATEST(expires_at,VALUES(expires_at))]],
          values = { reservation.field_id, cooldown, reservationId } },
        { query = 'DELETE FROM sfpj_player_links WHERE reservation_id=?', values = { reservationId } },
        { query = "UPDATE sfpj_reservation_members SET status='released',left_at=COALESCE(left_at,?) WHERE reservation_id=?",
          values = { timestamp, reservationId } },
        { query = 'DELETE FROM sfpj_field_claims WHERE reservation_id=?', values = { reservationId } },
        { query = [[UPDATE sfpj_reservations SET status='released',released_at=?,release_reason=? WHERE id=?]],
          values = { timestamp, reason, reservationId } },
    }
    if #removed > 0 then
        local placeholders, values = {}, {}
        for index, crop in ipairs(removed) do placeholders[index], values[index] = '?', crop.id end
        queries[#queries + 1] = {
            query = ('DELETE FROM sfpj_crops WHERE id IN (%s)'):format(table.concat(placeholders, ',')),
            values = values,
        }
    end
    local ok = MySQL.transaction.await(queries)
    if not ok then return false end
    for _, crop in ipairs(removed) do
        State.Remove(crop.id)
        Sync.OnCropRemoved(crop.id, crop.cell)
    end
    Fields.BroadcastInvalidate(reservation.field_id, reason)
    return true
end

function Reservations.Release(source, confirmed)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    if confirmed ~= true then return { ok = false, reason = 'confirmation_required' } end
    local link = Reservations.GetLink(actor.identifier)
    if not link or link.role ~= 'owner' then return { ok = false, reason = 'owner_required' } end
    local destroyed = liveCrops(link.reservation_id)
    return { ok = Reservations.Purge(link.reservation_id, 'released_early'), destroyed = destroyed }
end

function Reservations.InviteCandidates(source)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return nil, reason end
    local link = Reservations.GetLink(actor.identifier)
    if not link or link.role ~= 'owner' then return nil, 'owner_required' end
    local origin, output = playerCoords(source), {}
    for _, value in ipairs(GetPlayers()) do
        local candidate = tonumber(value)
        if candidate and candidate ~= source and distance(origin, playerCoords(candidate)) <= Config.Job.NearbyInviteDistance then
            local other = PublicJob.Guard(candidate)
            if other and not Reservations.GetLink(other.identifier) then
                output[#output + 1] = { source = candidate, name = other.name }
            end
        end
    end
    return output
end

function Reservations.Invite(source, targetSource)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    local target = PublicJob.Guard(tonumber(targetSource))
    if not target then return { ok = false, reason = 'invitee_unavailable' } end
    local link = Reservations.GetLink(actor.identifier)
    if not link or link.role ~= 'owner' then return { ok = false, reason = 'owner_required' } end
    if Reservations.GetLink(target.identifier) then return { ok = false, reason = 'already_participating' } end
    if distance(playerCoords(source), playerCoords(tonumber(targetSource))) > Config.Job.NearbyInviteDistance then
        return { ok = false, reason = 'invitee_too_far' }
    end
    local guests = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sfpj_reservation_members
        WHERE reservation_id=? AND role='guest' AND status IN ('active','departing')]], { link.reservation_id })) or 0
    if guests >= Config.Reservations.MaxGuests then return { ok = false, reason = 'guest_limit' } end
    local inviteId = Sonar.Utils.Uuid()
    MySQL.insert.await([[INSERT INTO sfpj_invites
        (id,reservation_id,inviter_identifier,invitee_identifier,status,expires_at)
        VALUES (?,?,?,?,'pending',?)]],
        { inviteId, link.reservation_id, actor.identifier, target.identifier, now() + Config.Reservations.InviteTtlSeconds })
    TriggerClientEvent('sonar_farm_publicjob:reservationInvite', tonumber(targetSource),
        { id = inviteId, inviter = actor.name, expiresAt = now() + Config.Reservations.InviteTtlSeconds })
    return { ok = true, inviteId = inviteId }
end

function Reservations.Accept(source, inviteId)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    local acquired, result = Lock.With('reservation:player:' .. actor.identifier, function()
        if Reservations.GetLink(actor.identifier) then return { ok = false, reason = 'already_participating' } end
        local invite = MySQL.single.await([[SELECT i.*,r.owner_identifier,r.field_id,r.status reservation_status
            FROM sfpj_invites i JOIN sfpj_reservations r ON r.id=i.reservation_id
            WHERE i.id=? AND i.invitee_identifier=? AND i.status='pending' AND i.expires_at>?]],
            { tostring(inviteId), actor.identifier, now() })
        if not invite or invite.reservation_status ~= 'active' then return { ok = false, reason = 'invite_expired' } end
        local ownerSource = PublicJob.SourceForIdentifier(invite.owner_identifier)
        if not ownerSource or distance(playerCoords(source), playerCoords(ownerSource)) > Config.Job.NearbyInviteDistance then
            return { ok = false, reason = 'inviter_too_far' }
        end
        local guests = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sfpj_reservation_members
            WHERE reservation_id=? AND role='guest' AND status IN ('active','departing')]], { invite.reservation_id })) or 0
        if guests >= Config.Reservations.MaxGuests then return { ok = false, reason = 'guest_limit' } end
        if tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sfpj_cooldowns
            WHERE identifier=? AND field_id=? AND expires_at>?]], { actor.identifier, invite.field_id, now() })) > 0 then
            return { ok = false, reason = 'field_cooldown' }
        end
        local memberLock, memberResult = Lock.With('reservation:members:' .. invite.reservation_id, function()
            local count = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sfpj_reservation_members
                WHERE reservation_id=? AND role='guest' AND status IN ('active','departing')]], { invite.reservation_id })) or 0
            if count >= Config.Reservations.MaxGuests then return { ok = false, reason = 'guest_limit' } end
            local committed = MySQL.transaction.await({
                { query = [[INSERT INTO sfpj_reservation_members
                    (reservation_id,identifier,display_name,role,status,joined_at) VALUES (?,?,?,'guest','active',?)]],
                  values = { invite.reservation_id, actor.identifier, actor.name, now() } },
                { query = "INSERT INTO sfpj_player_links (identifier,reservation_id,member_status) VALUES (?,?,'active')",
                  values = { actor.identifier, invite.reservation_id } },
                { query = "UPDATE sfpj_invites SET status='accepted' WHERE id=? AND status='pending'", values = { invite.id } },
            })
            if committed then
                Fields.BroadcastInvalidate(invite.field_id, 'member_joined')
                return { ok = true, reservation = Reservations.Snapshot(invite.reservation_id, actor.identifier) }
            end
            return { ok = false, reason = 'invite_conflict' }
        end)
        return memberLock and memberResult or { ok = false, reason = 'operation_in_progress' }
    end)
    return acquired and result or { ok = false, reason = 'operation_in_progress' }
end

lib.callback.register('sonar_farm_publicjob:reservation:accept', function(source, inviteId)
    return Reservations.Accept(source, inviteId)
end)

local function depart(actor, reservationId, targetIdentifier)
    if liveCrops(reservationId, targetIdentifier) > 0 then
        MySQL.transaction.await({
            { query = "UPDATE sfpj_reservation_members SET status='departing',left_at=? WHERE reservation_id=? AND identifier=?",
              values = { now(), reservationId, targetIdentifier } },
            { query = "UPDATE sfpj_player_links SET member_status='departing' WHERE identifier=? AND reservation_id=?",
              values = { targetIdentifier, reservationId } },
        })
        return { ok = true, status = 'departing' }
    end
    releaseMember(reservationId, targetIdentifier, 'released')
    return { ok = true, status = 'released' }
end

function Reservations.Leave(source)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    local link = Reservations.GetLink(actor.identifier)
    if not link then return { ok = false, reason = 'reservation_required' } end
    if link.role == 'owner' then return { ok = false, reason = 'owner_must_release' } end
    local result = depart(actor, link.reservation_id, actor.identifier)
    if result.ok then Fields.BroadcastInvalidate(link.field_id, 'member_left') end
    return result
end

function Reservations.Revoke(source, targetIdentifier)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    local link = Reservations.GetLink(actor.identifier)
    if not link or link.role ~= 'owner' then return { ok = false, reason = 'owner_required' } end
    local member = MySQL.single.await([[SELECT role,status FROM sfpj_reservation_members
        WHERE reservation_id=? AND identifier=?]], { link.reservation_id, tostring(targetIdentifier) })
    if not member or member.role ~= 'guest' or member.status ~= 'active' then return { ok = false, reason = 'member_not_found' } end
    local result = depart(actor, link.reservation_id, tostring(targetIdentifier))
    if result.ok then Fields.BroadcastInvalidate(link.field_id, 'member_revoked') end
    return result
end

function Reservations.ResolveAccess(source, fieldId, action, crop)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return nil, reason end
    local link = Reservations.GetLink(actor.identifier)
    if not link or link.field_id ~= fieldId then return nil, 'reservation_required' end
    local timestamp = now()
    if link.reservation_status == 'active' and tonumber(link.expires_at) <= timestamp then Reservations.Tick(timestamp); link = Reservations.GetLink(actor.identifier) end
    if not link or (link.reservation_status ~= 'active' and link.reservation_status ~= 'grace') then return nil, 'reservation_inactive' end
    if action == 'plant' then
        if link.reservation_status == 'grace' then return nil, 'reservation_grace' end
        if link.status ~= 'active' then return nil, 'member_departing' end
    elseif action == 'harvest' then
        if not crop or crop.owner ~= actor.identifier then return nil, 'crop_owner_required' end
    elseif link.status == 'departing' and (not crop or crop.owner ~= actor.identifier) then
        return nil, 'member_departing'
    end
    return { actor = actor, reservationId = link.reservation_id, memberRole = link.role,
        memberStatus = link.status, reservationStatus = link.reservation_status }
end

function Reservations.OnCropRemoved(reservationId)
    local reservation = MySQL.single.await('SELECT status FROM sfpj_reservations WHERE id=?', { reservationId })
    if not reservation then return end
    for _, member in ipairs(rows([[SELECT identifier FROM sfpj_reservation_members
        WHERE reservation_id=? AND status='departing']], { reservationId })) do
        if liveCrops(reservationId, member.identifier) == 0 then releaseMember(reservationId, member.identifier, 'released') end
    end
    if reservation.status == 'grace' and liveCrops(reservationId) == 0 then Reservations.Purge(reservationId, 'grace_harvested') end
end

function Reservations.Tick(timestamp)
    timestamp = tonumber(timestamp) or now()
    for _, reservation in ipairs(rows([[SELECT * FROM sfpj_reservations
        WHERE status='active' AND expires_at<=?]], { timestamp })) do
        if liveCrops(reservation.id) == 0 then Reservations.Purge(reservation.id, 'expired_empty')
        else
            local graceUntil = (tonumber(reservation.expires_at) or timestamp) + Config.Reservations.GraceSeconds
            if graceUntil <= timestamp then
                Reservations.Purge(reservation.id, 'grace_expired')
            else
                MySQL.update.await([[UPDATE sfpj_reservations SET status='grace',grace_until=?
                    WHERE id=? AND status='active']], { graceUntil, reservation.id })
                Fields.BroadcastInvalidate(reservation.field_id, 'grace_started')
            end
        end
    end
    for _, reservation in ipairs(rows([[SELECT id FROM sfpj_reservations
        WHERE status='grace' AND grace_until<=?]], { timestamp })) do Reservations.Purge(reservation.id, 'grace_expired') end
    MySQL.update.await('DELETE FROM sfpj_invites WHERE status=\'pending\' AND expires_at<=?', { timestamp })
    MySQL.update.await('DELETE FROM sfpj_cooldowns WHERE expires_at<=?', { timestamp })
end

function Reservations.Init()
    Reservations.Tick(now())
    return true
end
