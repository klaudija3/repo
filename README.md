# Spletna trgovina

Spletna aplikacija za spletno trgovino, razvita v okviru predmeta **Razvoj programske opreme**.

Projekt je osredotočen na razvoj funkcionalne spletne trgovine z uporabo sodobnih spletnih tehnologij in iterativnega pristopa k razvoju po metodologiji Scrum.

## Uporabljene tehnologije

| Komponenta                                 | Tehnologija       | Opis                                                                         |
| ------------------------------------------ | ----------------- | ---------------------------------------------------------------------------- |
| Podatkovna baza                            | PostgreSQL        | Odprtokodna relacijska podatkovna baza                                       |
| Zaledni del (Backend)                      | Python, Flask     | Lahek spletni ogrodni sistem za razvoj REST API-jev                          |
| Uporabniški vmesnik (Frontend)             | Vue.js            | JavaScript ogrodje za razvoj odzivnih uporabniških vmesnikov                 |
| Upravljanje različic                       | Git, GitHub       | Upravljanje izvorne kode in sodelovanje pri razvoju                          |
| Upravljanje nalog                          | Jira              | Načrtovanje sprintov in spremljanje nalog                                    |
| Povratni proxy / uravnoteženje obremenitve | Nginx             | Usmerjanje zahtevkov in posredovanje prometa med storitvami                  |
| Zunanji dostop                             | Cloudflare Tunnel | Varna zunanja dostopnost aplikacije brez neposrednega odpiranja vhodnih vrat |

## Arhitektura

Aplikacija temelji na arhitekturi odjemalec-strežnik:

* **Frontend:** Vue.js skrbi za uporabniški vmesnik in komunikacijo z zalednim delom prek zahtevkov REST API.

* **Backend:** Flask zagotavlja REST API, obdeluje poslovno logiko, avtentikacijo in komunikacijo s podatkovno bazo.

* **Podatkovna baza:** PostgreSQL shranjuje podatke o izdelkih, uporabnikih, nakupovalnih košaricah in naročilih.

* **Nginx:** Deluje kot povratni proxy in usmerja vhodne zahtevke do ustreznih storitev.

* **Cloudflare Tunnel:** Omogoča varen zunanji dostop do aplikacije.

## Funkcionalnosti

* Prikaz izdelkov in njihovih podrobnosti

* Iskanje, filtriranje in razvrščanje izdelkov

* Registracija uporabnikov in prijava

* Upravljanje nakupovalne košarice

* Oddaja in upravljanje naročil

* Shranjevanje podatkov v podatkovno bazo

* Odziven uporabniški vmesnik

## Struktura projekta

```
web-shop/
├── backend/          # Flask REST API
├── frontend/         # Vue.js aplikacija
├── database/         # Skripte in inicializacija podatkovne baze
├── nginx/            # Konfiguracija Nginx
├── docs/             # Projektna dokumentacija
└── README.md
```

## Namestitev in zagon

Navodila za namestitev in zagon aplikacije bomo dodali med nadaljnjim razvojem projekta.
