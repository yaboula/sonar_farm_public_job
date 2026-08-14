-- Version-controlled public Field catalogue. MySQL owns active revisions after import.

Config.FieldSeeds = {
    -- [[ EJEMPLO DE CAMPO (Plantilla) ]]
    -- Descomenta este bloque y rellena con tus coordenadas reales
    --[[
    {
        id = 'mi_campo_01',             -- ID único del campo en la base de datos (sin espacios)
        legacyZone = 'mi_campo_01',     -- Mismo ID
        name = 'Campo Central',         -- Nombre visible para los jugadores en la Tablet
        location = 'Granja Los Santos', -- Ubicación visible en la Tablet
        region = 'Los Santos',          -- Región (Ej: Paleto, Grapeseed, Los Santos)
        sizeClass = 'S',                -- Tamaño: 'S' (Pequeño), 'M' (Mediano), 'L' (Grande)
        orientation = 0.0,              -- Orientación general visual
        catalogVisible = true,          -- true para que aparezca en el mercado de reservas
        allowedCrops = { 'carrot', 'potato', 'lettuce', 'tomato' }, -- Cultivos permitidos (vacío {} para permitir todos)
        
        -- Coordenada del punto de acceso (Donde se asume la entrada al campo)
        access = { x = 0.0, y = 0.0, z = 0.0 },
        
        -- Cuadrícula (Grid) donde aparecerán físicamente las plantas
        grid = { 
            origin = { x = 0.0, y = 0.0, z = 0.0 }, -- Coordenada de origen (donde empieza la cuadrícula)
            rows = 4,                               -- Número de filas de plantas
            cols = 6,                               -- Número de columnas de plantas
            spacing = { x = 2.2, y = 2.8 },         -- Espacio (en metros) entre plantas en x e y
            heading = 0.0                           -- Rotación (heading) de toda la cuadrícula
        },
        
        -- Blip en el mapa
        blip = { enabled = true, sprite = 496, color = 25, scale = 0.8 },
    }
    ]]
}
