-- Выполните этот файл целиком: Supabase → SQL Editor → New query → Run
-- Создаёт таблицы, правила безопасности (RLS) и загружает 156 товаров из alfacomp.csv

create table if not exists public.products (
  id         integer primary key,
  name       text not null,
  brand      text,
  category   text not null,
  price      numeric(12,2) not null,
  in_stock   boolean not null default true,
  priority   integer not null default 0,
  photo_url  text,                         -- ссылка на фото товара (см. README)
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  telegram_id     bigint primary key,
  first_name      text,
  username        text,
  phone           text,
  contact_consent boolean not null default false,
  consent_at      timestamptz,
  created_at      timestamptz not null default now()
);

-- RLS: каталог бот (anon) может только читать; клиентов не может читать вообще
alter table public.products  enable row level security;
alter table public.customers enable row level security;

drop policy if exists "anon read products" on public.products;
create policy "anon read products" on public.products for select to anon using (true);

-- Запись клиентов — только через функции ниже
create or replace function public.register_customer(
  p_telegram_id bigint, p_first_name text, p_username text, p_phone text, p_consent boolean
) returns void language sql security definer set search_path = public as $$
  insert into public.customers (telegram_id, first_name, username, phone, contact_consent, consent_at)
  values (p_telegram_id, p_first_name, p_username, p_phone, p_consent, case when p_consent then now() end)
  on conflict (telegram_id) do update set
    first_name = excluded.first_name, username = excluded.username, phone = excluded.phone,
    contact_consent = excluded.contact_consent, consent_at = excluded.consent_at;
$$;

create or replace function public.forget_customer(p_telegram_id bigint)
returns void language sql security definer set search_path = public as $$
  delete from public.customers where telegram_id = p_telegram_id;
$$;

revoke all on function public.register_customer(bigint, text, text, text, boolean) from public;
revoke all on function public.forget_customer(bigint) from public;
grant execute on function public.register_customer(bigint, text, text, text, boolean) to anon;
grant execute on function public.forget_customer(bigint) to anon;

-- Товары
insert into public.products (id, name, brand, category, price, in_stock, priority) values
(162, 'ATK A9 AIR ORANGE', null, 'Мышки', 65, true, 0),
(165, 'Aula v9 ultra 33$', null, 'Мышки', 33, true, 0),
(166, 'Mirage R73', 'Bloody', 'Мышки', 38, true, 0),
(167, 'S87', 'Bloody', 'Аксессуары', 44, true, 0),
(168, 'Renagade R72 ULTRA DUO', 'Bloody', 'Мышки', 41, true, 0),
(169, 'R90 Plus', 'Bloody', 'Мышки', 26, true, 0),
(170, 'V7M71', 'Bloody', 'Мышки', 20, true, 0),
(171, 'V8MA', 'Bloody', 'Мышки', 16, true, 0),
(172, 'Archer A8', 'TP-Link', 'Wi-Fi роутеры', 33, true, 0),
(173, 'Archer AX53', 'TP-Link', 'Wi-Fi роутеры', 50, true, 0),
(174, 'Wi-Fi 7 BE3600', 'TP-Link', 'Wi-Fi роутеры', 84, true, 0),
(175, 'Hopestar A85 + Microphone', 'Hopestar', 'Колонки', 179, true, 0),
(176, 'Hopestar A40', 'Hopestar', 'Колонки', 82, true, 0),
(177, 'Hopestar A30 PARTY', 'Hopestar', 'Колонки', 56, true, 0),
(178, 'Hopestar A6 CLUB + Microphone', 'Hopestar', 'Колонки', 127, true, 0),
(179, 'Hopestar A6 PRO', 'Hopestar', 'Колонки', 72, true, 0),
(180, 'Hopestar H87', 'Hopestar', 'Колонки', 57, true, 0),
(181, 'Hopestar H63', 'Hopestar', 'Колонки', 62, true, 0),
(182, 'Hopestar H61', 'Hopestar', 'Колонки', 53, true, 0),
(183, 'Hopestar H57', 'Hopestar', 'Колонки', 34, true, 0),
(184, 'Hopestar H53 PRO', 'Hopestar', 'Колонки', 58, true, 0),
(185, 'Hopestar P64 PRO', 'Hopestar', 'Колонки', 54, true, 0),
(186, 'Hopestar P52', 'Hopestar', 'Колонки', 37, true, 0),
(187, 'Hopestar P50', 'Hopestar', 'Колонки', 32, true, 0),
(188, 'PARTY BOX 150', 'Hopestar', 'Колонки', 50, true, 0),
(189, 'PARTY BOX + 2 Microphone', 'Hopestar', 'Колонки', 129, true, 0),
(190, 'PARTY 500 + 2 Microphone', 'Hopestar', 'Колонки', 101, true, 0),
(1, 'Ion 600t-33', 'Ion', 'ИБП', 33, true, 1),
(2, 'Ion a600-35', 'Ion', 'ИБП', 35, true, 2),
(3, 'Ion a800-46', 'Ion', 'ИБП', 46, true, 3),
(4, 'Ion a1500-105', 'Ion', 'ИБП', 105, true, 4),
(5, 'Ion a2000-145', 'Ion', 'ИБП', 145, true, 5),
(6, 'Ion v650 -41', 'Ion', 'ИБП', 41, true, 6),
(7, 'Ion v850-54', 'Ion', 'ИБП', 54, true, 7),
(8, 'Ion v1000t-67', 'Ion', 'ИБП', 67, true, 8),
(9, 'Ion v1000-78', 'Ion', 'ИБП', 78, true, 9),
(10, 'Ion v1000lcd 85', 'Ion', 'ИБП', 85, true, 10),
(11, 'Ion v1200t-88', 'Ion', 'ИБП', 88, true, 11),
(12, 'Ion v2000-185', 'Ion', 'ИБП', 185, true, 12),
(13, 'Ion v2000lcd -190', 'Ion', 'ИБП', 190, true, 13),
(14, 'Ion v3000 lcd -335', 'Ion', 'ИБП', 335, true, 14),
(15, 'Ion G2000lcd -440', 'Ion', 'ИБП', 440, true, 15),
(16, 'Ion g3000lcd 550', 'Ion', 'ИБП', 550, true, 16),
(17, 'Ion g6000 v2 lcd -1230', 'Ion', 'ИБП', 1230, true, 17),
(18, 'Ion g10.000 v2 lcd -1500', 'Ion', 'ИБП', 1500, true, 18),
(19, 'Ion wp 1000lcd -230', 'Ion', 'ИБП', 230, true, 19),
(20, 'Ion wp 2000lcd -440', 'Ion', 'ИБП', 440, true, 20),
(21, 'Ion wp 3000lcd -540', 'Ion', 'ИБП', 540, true, 21),
(22, 'Ion wp 6000lcd -1200', 'Ion', 'ИБП', 1200, true, 22),
(23, 'Ion wp 10.000 lcd -1400', 'Ion', 'ИБП', 1400, true, 23),
(24, 'Ion 20KVA G3 PRO', 'Ion', 'ИБП', 3800, true, 24),
(25, 'ION 30KVA G3 PRO', 'Ion', 'ИБП', 4900, true, 25),
(26, 'ION 40KVA G3 PRO', 'Ion', 'ИБП', 5950, true, 26),
(27, 'ION 80KVA 64KW', 'Ion', 'ИБП', 13000, true, 27),
(28, 'ION 120KVA 96KW', 'Ion', 'ИБП', 19000, true, 28),
(29, 'REDMI G27Q 2K 200HZ', 'Redmi', 'Мониторы', 165, true, 29),
(32, 'Redmi x27g', 'Redmi', 'Мониторы', 110, true, 30),
(30, 'Philips 27m2n3500', 'Philips', 'Мониторы', 195, true, 31),
(31, 'Philips 27m2n3500uf', 'Philips', 'Мониторы', 225, true, 32),
(154, 'VG249QG FHD IPS 120HZ', 'ASUS', 'Мониторы', 135, true, 33),
(33, 'Mercusys 4g LTE', 'Mercusys', 'Сеть', 26, true, 34),
(34, 'Mercusys ms108gp poe', 'Mercusys', 'Сеть', 25, true, 35),
(35, 'MERCUSYS MR80X', 'Mercusys', 'Сеть', 32, true, 36),
(36, 'Mercusy mr70x ax1800 wifi6', 'Mercusys', 'Сеть', 31, true, 37),
(37, 'Mercusys MR62X', 'Mercusys', 'Сеть', 22, true, 38),
(38, 'Mercusys MR60X', 'Mercusys', 'Сеть', 23, true, 39),
(39, 'MERCUSYS MR47BE', 'Mercusys', 'Сеть', 125, true, 40),
(40, 'Mercusys WIFI 7 MR27BE', 'Mercusys', 'Сеть', 55, true, 41),
(41, 'Mercusys WIFI 7 MR25BE', 'Mercusys', 'Сеть', 50, true, 42),
(42, 'Mercusys MB130-4G', 'Mercusys', 'Сеть', 30, true, 43),
(43, 'Mercusys MB115-4G', 'Mercusys', 'Сеть', 30, true, 44),
(44, 'Mercusys WI-FI 6E MA86XE', 'Mercusys', 'Сеть', 22, true, 45),
(45, 'MERCUSYS WIFI 6E MA80XE', 'Mercusys', 'Сеть', 21, true, 46),
(46, 'MERCUSYS WIFI 6E MA70XE', 'Mercusys', 'Сеть', 17, true, 47),
(47, 'MERCUSYS WI-FI 6E HALO H80X 3Pck', 'Mercusys', 'Сеть', 90, true, 48),
(48, 'MERCUSYS WI-FI 6E HALO H70X 3Pck', 'Mercusys', 'Сеть', 90, true, 49),
(49, 'MERCUSYS WI-FI 6E HALO H60X 3Pck', 'Mercusys', 'Сеть', 65, true, 50),
(50, 'MERCUSYS WI-FI 6E HALO H50g 3Pck', 'Mercusys', 'Сеть', 65, true, 51),
(51, 'MERCUSYS HALO WI-FI 7 H27BE (3-PACK)', 'Mercusys', 'Сеть', 130, true, 52),
(151, 'Lexar THOR 128 GB (64x2) 6000 mhz', 'Lexar', 'Комплектующие', 2050, true, 53),
(149, 'Lexar THOR RGB DDR5 64GB 6000MHz', 'Lexar', 'Комплектующие', 950, true, 54),
(153, 'KINGSTON 32GB 3600 DDR4', 'KINGSTON', 'Комплектующие', 170, true, 55),
(52, '4tb 990 pro', 'Samsung', 'Комплектующие', 400, true, 56),
(53, '4tb kingston', 'Kingston', 'Комплектующие', 320, true, 57),
(54, 'Wd red plus 12TB', 'WD', 'Комплектующие', 335, true, 58),
(55, 'WD RED PLUS 10TB', 'WD', 'Комплектующие', 299, true, 59),
(56, 'WD RED PLUS 8TB', 'WD', 'Комплектующие', 220, true, 60),
(57, 'WD RED PLUS 4TB', 'WD', 'Комплектующие', 190, true, 61),
(58, 'Wd MY PASSPORT 5TB USB', 'WD', 'Комплектующие', 140, true, 62),
(59, 'usb hdd apacer 1tb', 'Apacer', 'Комплектующие', 60, true, 63),
(60, 'Usb hdd apacer 2tb', 'Apacer', 'Комплектующие', 75, true, 64),
(61, 'Usb ssd 1tb', 'Generic', 'Комплектующие', 100, true, 65),
(62, 'Usp ssd 2tb', 'Generic', 'Комплектующие', 1, true, 66),
(63, 'Msi h610', 'MSI', 'Комплектующие', 57, true, 67),
(64, 'ULTRA 9285K', 'Intel', 'Комплектующие', 550, true, 68),
(65, 'I7 -14700K', 'Intel', 'Комплектующие', 350, true, 69),
(66, 'I7 14700kf', 'Intel', 'Комплектующие', 320, true, 70),
(67, 'I9 13900k', 'Intel', 'Комплектующие', 395, true, 71),
(68, 'Asus RTX 5060 OC 8GB', 'ASUS', 'Комплектующие', 350, true, 72),
(69, 'ZOTAG GAMING RTX5060 8GB', 'ZOTAC', 'Комплектующие', 340, true, 73),
(70, 'Acer AIO 23.8 IPS 120HZ', 'Acer', 'Моноблоки', 515, true, 74),
(71, 'Acer AIO 27 IPS 120HZ', 'Acer', 'Моноблоки', 620, true, 75),
(72, 'LENOVO AIO 23.8 100HZ IPS', 'Lenovo', 'Моноблоки', 660, true, 76),
(73, 'LENOVO AIO 23.8 100HZ IPS v2', 'Lenovo', 'Моноблоки', 660, true, 77),
(74, 'Usb DVD', 'Generic', 'Аксессуары', 32, true, 78),
(75, 'Aula F75 3 IN 1 GASKET KEYBOARD', 'Aula', 'Аксессуары', 50, true, 79),
(76, 'Aula f75 ru RED SWITCH', 'Aula', 'Аксессуары', 35, true, 80),
(77, 'Aula f99 pro ru', 'Aula', 'Аксессуары', 60, true, 81),
(78, 'Aula s98 pro ru', 'Aula', 'Аксессуары', 60, true, 82),
(79, 'Aula sc380 pro', 'Aula', 'Аксессуары', 25, true, 83),
(161, 'Aula sc380 pro', 'Aula', 'Мышки', 25, true, 83),
(80, 'Yandex stansiya 3', 'Yandex', 'Аксессуары', 320, true, 84),
(81, 'YANDEX MAX 65W', 'Yandex', 'Аксессуары', 370, true, 85),
(82, 'Sony M6 Black', 'Sony', 'Аксессуары', 330, true, 86),
(83, 'Hopestor A85', 'Hopestar', 'Колонки', 85, true, 87),
(84, 'Hopestor A80', 'Hopestar', 'Колонки', 65, true, 88),
(101, 'LDT101-C012 White+Blue 24-57 up to 30kg', 'LDT', 'Кронштейны', 56, true, 89),
(102, 'LDT99-C024 White 24-45 up to 27kg', 'LDT', 'Кронштейны', 96, true, 90),
(103, 'LDT99-C012 White 24-57 up to 27kg', 'LDT', 'Кронштейны', 51, true, 91),
(104, 'LDT95-C012 Black+White 24-57 up to 30kg', 'LDT', 'Кронштейны', 51, true, 92),
(105, 'LDT94-C012E White 17-40 up to 12kg', 'LDT', 'Кронштейны', 19, true, 93),
(106, 'LDT93-C012 Black+White 17-45 up to 16kg', 'LDT', 'Кронштейны', 30, true, 94),
(107, 'LDT88-C012 Space Grey+White 17-32 up to 9kg', 'LDT', 'Кронштейны', 16, true, 95),
(108, 'LDT85-C024 White 17-35 up to 20kg', 'LDT', 'Кронштейны', 86, true, 96),
(109, 'LDT85-C012L White 17-49 up to 20kg RGB Gaming', 'LDT', 'Кронштейны', 64, true, 97),
(111, 'LDT81N-C024 White 17-35 up to 20kg', 'LDT', 'Кронштейны', 82, true, 98),
(112, 'LDT81N-C012 White 17-49 up to 20kg', 'LDT', 'Кронштейны', 43, true, 99),
(113, 'LDT39-C024 Black 17-32 up to 8kg', 'LDT', 'Кронштейны', 75, true, 100),
(114, 'LDT39-C012U Black 17-32 up to 8kg', 'LDT', 'Кронштейны', 81, true, 101),
(115, 'LDT39-C012 Black 17-32 up to 8kg', 'LDT', 'Кронштейны', 43, true, 102),
(118, 'LDT85-C012-KP01 White 17-40 up to 12kg', 'LDT', 'Кронштейны', 43, true, 103),
(119, 'Deco X68 (1-pack) AX3600 Tri-Band', 'TP-Link', 'Deco', 107, true, 104),
(120, 'Deco X60 (3-pack) AX5400', 'TP-Link', 'Deco', 286, true, 105),
(121, 'Deco X60 (2-pack) AX5400', 'TP-Link', 'Deco', 200, true, 106),
(122, 'Deco X60 (1-pack) AX5400', 'TP-Link', 'Deco', 107, true, 107),
(123, 'Deco X55 (3-pack) AX3000 Tri-Band', 'TP-Link', 'Deco', 229, true, 108),
(124, 'Deco X55 (2-pack) AX3000', 'TP-Link', 'Deco', 157, true, 109),
(125, 'Deco X55 (1-pack) AX3000', 'TP-Link', 'Deco', 86, true, 110),
(126, 'Deco X50 Pro (3-pack) AX3000', 'TP-Link', 'Deco', 250, true, 111),
(127, 'Deco X50 Pro (2-pack) AX3000', 'TP-Link', 'Deco', 186, true, 112),
(128, 'Deco X50 Pro (1-pack) AX3000', 'TP-Link', 'Deco', 107, true, 113),
(129, 'Deco X50 (3-pack) AX3000', 'TP-Link', 'Deco', 214, true, 114),
(130, 'Deco X50 (2-pack) AX3000', 'TP-Link', 'Deco', 150, true, 115),
(131, 'Deco X50 (1-pack) AX3000', 'TP-Link', 'Deco', 79, true, 116),
(132, 'Deco PX50 (3-pack) AX3000 + Powerline', 'TP-Link', 'Deco', 271, true, 117),
(133, 'Deco PX50 (2-pack) AX3000 + Powerline', 'TP-Link', 'Deco', 193, true, 118),
(134, 'Deco X20 (3-pack) AX1800', 'TP-Link', 'Deco', 200, true, 119),
(135, 'Deco X20 (2-pack) AX1800', 'TP-Link', 'Deco', 143, true, 120),
(136, 'Deco X20 (1-pack) AX1800', 'TP-Link', 'Deco', 79, true, 121),
(137, 'Deco X10 (3-pack) AX1500', 'TP-Link', 'Deco', 136, true, 122),
(138, 'Deco X10 (2-pack) AX1500', 'TP-Link', 'Deco', 100, true, 123),
(139, 'Deco X10 (1-pack) AX1500', 'TP-Link', 'Deco', 54, true, 124),
(140, 'Archer AX73 AX5400 Dual-Band Wi-Fi 6 Router', 'TP-Link', 'Wi-Fi роутеры', 157, true, 125),
(141, 'Archer AX72 Pro AX5400 Dual-Band Wi-Fi 6 Router', 'TP-Link', 'Wi-Fi роутеры', 88, true, 126),
(142, 'Archer AX72 AX5400 Dual-Band Wi-Fi 6 Router', 'TP-Link', 'Wi-Fi роутеры', 84, true, 127),
(143, 'Archer AX55 AX3000 Dual-Band Wi-Fi 6 Router', 'TP-Link', 'Wi-Fi роутеры', 57, true, 128)
on conflict (id) do update set
  name = excluded.name, brand = excluded.brand, category = excluded.category,
  price = excluded.price, in_stock = excluded.in_stock, priority = excluded.priority;
