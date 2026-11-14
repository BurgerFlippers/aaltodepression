# Usual: tiimin suunnitelma (hyväksyttäväksi)

**Pitch:** Usual ei kerro sinulle, että voit huonosti. Se löytää illan, jolloin vastaisit puhelimeen, ja kertoo sen ihmisille, jotka välittävät sinusta.

**Kulku:** 5 drift-päivää 7:stä → hyvä hetki löytyy → viesti läheiselle → läheinen soittaa.

Prototyypissä viestiä ei oikeasti lähetetä. Sovellus näyttää, mikä viesti lähtisi ja milloin. Ilmoitukset esitysmateriaaliin ja videoon tehdään erikseen.

## Onboarding (kerran, alle 2 min)
- **Läheiset:** 2–4 henkilöä iOS:n yhteystietovalitsimella, joka ei vaadi lupaa. Chipit "Vanhempi", "Sisarus", "Kumppani" ja "Ystävä" avaavat haun.
- **Soittoajat:** aamu, iltapäivä tai ilta × arki tai viikonloppu, sekä kotona, ulkona tai molemmat.
- **Viestin teksti:** valmis pohja, jota voi muokata. Viestissä ei mainita terveyttä.
- **Luvat:** Health, liike ja sijainti, kuten nyt.

## Home (päivittäin)
- **Tavallinen päivä:** yksi hiljainen tilarivi.
- **Soittokortti** (askel 1): "Viesti Villelle to 18:00. Olet silloin yleensä kotona ja hereillä." Vaihtoehdot ovat Peru ja Joku muu.
- **Toimenpide:** yksi ehdotus hoitosuunnitelmasta, kuten nyt.
- **Aamukysymys** soittoikkunan jälkeen: "Juttelitko jonkun kanssa?"

## Settings
- Läheiset, soittoajat ja viestin teksti
- Tauko viikoksi
- Hoitaja ja hoitosuunnitelma
- Kriisipuhelin (MIELI 09 2525 0111, 112) ja teksti "Kukaan ei seuraa tätä reaaliajassa."
- Datalähteet ja luvat

## Demo
- Nykyiset Today- ja Plan-näkymät, demopäivän valinta ja "Simulate a breathing session"
- **Hyppää päivään 49:** Home näyttää soittokortin Perttun datalla.
- **Viestin esikatselu:** miltä viesti näyttäisi läheisen puhelimessa (videota ja kalvoja varten).

## Taustalla
- **~25 signaalia** nykyisten noin 100:n sijaan ([DATA_SCOPE.md](DATA_SCOPE.md)). Calendar ja Photos poistetaan.
- **Laukaisu:** kun viimeisistä 7 päivästä 5 on driftannut (askel 1). Hoitaja tulee mukaan, jos drifti jatkuu vielä 10 päivää (askel 2).
- **`CallWindowFinder`:** valitsee seuraavista 36 tunnista tunnin, joka on toivotuissa ajoissa ja jolloin käyttäjä on tavallisesti kotona tai ulkona toiveen mukaan ja hereillä. Tämä opitaan sijainnista, unesta ja tuntiaskelista.
- **Rajat:** enintään yksi viesti kahden päivän välein, sama läheinen enintään kerran viikossa ja läheisiä kierrätetään. Ei yöllä.
- **Oppiminen:** aamukysymyksestä nähdään, mitkä ajat johtivat puheluun. Lisäksi seurataan, kenen kanssa puhumisen jälkeiset päivät olivat tasaisempia. Tämä näytetään vain käyttäjälle.

## Työnjako (noin 24 h)
Ensin 30 minuutissa sovitaan mallit `CallSetup` (läheiset, ajat, teksti) ja `CallWindow` (aika, läheinen, syy).

| Osa | Sisältö | Arvio | Tekijä |
|---|---|---|---|
| Onboarding | Läheisten valinta, soittoaikaruudukko, viestiteksti, CallSetup-tallennus | 5 h | ? |
| Home | Tilarivi, soittokortti, toimenpide, aamukysymys | 4 h | ? |
| Settings | Muokkausnäkymät, tauko, hoitaja, kriisipuhelin, datalähteet | 3 h | ? |
| Demo | Välilehtirakenne, nykyiset näkymät Demo-välilehdelle, päivähyppy, viestin esikatselu | 3 h | ? |
| Moottori | CallWindowFinder, kotona-tunneittain-profiili, rajat, Perttun demodata, testit | 5 h | ? |
| Signaalit | Karsinta noin 25 signaaliin, `engine-check.sh` näyttää yhä askeleet päivinä 49 ja 59 | 4 h | ? |

## Ei prototyypissä
- **Oikea viestien lähetys** (palvelin ja SMS). Ilmoitukset tehdään keinotekoisesti esitykseen ja videoon.
- **Läheisten suostumusviesti** ja läheisen oma sovellus
- **Kriisin tunnistus sensoreista**
