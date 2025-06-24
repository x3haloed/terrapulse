-- Create a sample game
INSERT INTO public.games (id, name, status, next_tick_at)
VALUES ('00000000-0000-0000-0000-000000000001', 'Global Conquest', 'active', now() + interval '24 hours');

-- Continents: North America, South America, Europe, Africa, Asia, Australia

-- North America (9 territories)
INSERT INTO public.territories (game_id, name, continent) VALUES
('00000000-0000-0000-0000-000000000001', 'Alaska', 'North America'),
('00000000-0000-0000-0000-000000000001', 'Northwest Territory', 'North America'),
('00000000-0000-0000-0000-000000000001', 'Greenland', 'North America'),
('00000000-0000-0000-0000-000000000001', 'Alberta', 'North America'),
('00000000-0000-0000-0000-000000000001', 'Ontario', 'North America'),
('00000000-0000-0000-0000-000000000001', 'Quebec', 'North America'),
('00000000-0000-0000-0000-000000000001', 'Western United States', 'North America'),
('00000000-0000-0000-0000-000000000001', 'Eastern United States', 'North America'),
('00000000-0000-0000-0000-000000000001', 'Central America', 'North America');

-- South America (4 territories)
INSERT INTO public.territories (game_id, name, continent) VALUES
('00000000-0000-0000-0000-000000000001', 'Venezuela', 'South America'),
('00000000-0000-0000-0000-000000000001', 'Peru', 'South America'),
('00000000-0000-0000-0000-000000000001', 'Brazil', 'South America'),
('00000000-0000-0000-0000-000000000001', 'Argentina', 'South America');

-- Europe (7 territories)
INSERT INTO public.territories (game_id, name, continent) VALUES
('00000000-0000-0000-0000-000000000001', 'Great Britain', 'Europe'),
('00000000-0000-0000-0000-000000000001', 'Iceland', 'Europe'),
('00000000-0000-0000-0000-000000000001', 'Northern Europe', 'Europe'),
('00000000-0000-0000-0000-000000000001', 'Scandinavia', 'Europe'),
('00000000-0000-0000-0000-000000000001', 'Southern Europe', 'Europe'),
('00000000-0000-0000-0000-000000000001', 'Ukraine', 'Europe'),
('00000000-0000-0000-0000-000000000001', 'Western Europe', 'Europe');

-- Africa (6 territories)
INSERT INTO public.territories (game_id, name, continent) VALUES
('00000000-0000-0000-0000-000000000001', 'Congo', 'Africa'),
('00000000-0000-0000-0000-000000000001', 'East Africa', 'Africa'),
('00000000-0000-0000-0000-000000000001', 'Egypt', 'Africa'),
('00000000-0000-0000-0000-000000000001', 'Madagascar', 'Africa'),
('00000000-0000-0000-0000-000000000001', 'North Africa', 'Africa'),
('00000000-0000-0000-0000-000000000001', 'South Africa', 'Africa');

-- Asia (12 territories)
INSERT INTO public.territories (game_id, name, continent) VALUES
('00000000-0000-0000-0000-000000000001', 'Afghanistan', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'China', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'India', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Irkutsk', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Japan', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Kamchatka', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Middle East', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Mongolia', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Siam', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Siberia', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Ural', 'Asia'),
('00000000-0000-0000-0000-000000000001', 'Yakutsk', 'Asia');

-- Australia (4 territories)
INSERT INTO public.territories (game_id, name, continent) VALUES
('00000000-0000-0000-0000-000000000001', 'Eastern Australia', 'Australia'),
('00000000-0000-0000-0000-000000000001', 'Indonesia', 'Australia'),
('00000000-0000-0000-0000-000000000001', 'New Guinea', 'Australia'),
('00000000-0000-0000-0000-000000000001', 'Western Australia', 'Australia'); 