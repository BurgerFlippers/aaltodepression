# Usual: mitä dataa kerätään (ehdotus hyväksyttäväksi)

Pohjana on research-ajo, jossa oli neljä näkökulmaa: tutkimusnäyttö, iOS:n toteutettavuus, yksityisyys ja hyväksyttävyys sekä sopivuus haasteeseen ja arviointikriteereihin. Lisäksi luonnoksen kävi läpi kaksi kriitikkoa: yksityisyysskeptikko ja Junction-tuomari. Lähdeviitteet ovat agenttien hakemia, eikä niitä ole vielä tarkistettu yksitellen. Tarkista ne ennen kuin niitä käytetään pitchissä.

## Periaatteet

1. **Vain päiväluvut.** Raakadata jää HealthKitiin, ja Usual tallentaa yhden luvun per signaali per päivä. Signaaleja on noin 25, kun nykyisin niitä on noin 100.
2. **Sisältöä ei koskaan lueta.** Viestejä, kalenteria, kuvia, ääntä tai kamerakuvaa ei tallenneta. Vapaaehtoisista mittauksista (C-taso) jää vain luvut.
3. **Ensin puhelin, wearable lisänä.** Steadiness toimii pelkällä iPhonella. Watch tai sormus tarkentaa. Jokaisella lähteellä on oma baseline, joten Watchin ja Ouran HRV-arvoja ei sekoiteta keskenään.
4. **Puuttuva data ei ole koskaan drifti.** Sama koskee klinikkaa: hiljaisuus ei käynnistä yhteydenottoa.
5. **Itseraportointia ei pisteytetä.** Se näytetään vertailuna, ja se voi korkeintaan kalibroida painoja (ks. Avoimet päätökset 2).
6. **Jokainen lähde pyydetään erikseen ja on peruttavissa.** Herkkä data on tasolla C, ja siihen on lisäksi "Pysäytä 7 päiväksi".

## Taso A: ydin (iPhone + HealthKit, ei wearablea)

| Signaali | Lähde | Miksi | Muutos |
|---|---|---|---|
| Askeleet + tuntiaskeleet | HealthKit `stepCount` | Liike, vuorokausirytmi | Pidä. Tuntitason dataa säilytetään vain 14 päivää. |
| Aktiiviset tunnit, ensimmäinen/viimeinen aktiivinen tunti | Lasketaan tuntiaskelista | Rytmi | Ensimmäinen ja viimeinen tunti uusia |
| **Interdaily stability / intradaily variability** | Lasketaan tuntiaskelista | Rytmin säännöllisyys (Saeb 2015, Stamatis 2024; korreloi oireisiin, ei ennusta) | **Uusi** |
| Kävelynopeus | HealthKit `walkingSpeed` | Psykomotorinen hidastuminen (kohtalainen näyttö) | Pidä |
| Kävely-/paikallaanolotunnit | Core Motion | Liike | Tallennetaan päivittäin, koska iOS säilyttää vain 7 päivää |
| Kotona/poissa, paikat, max km, entropia | Core Location visits | Vahvin passiivinen ennakkomerkki: kotona tavallista enemmän → oireet 1–2 vk myöhemmin (Stamatis 2024) | Pidä. Koordinaatit poistetaan yöllisen laskennan jälkeen. Talteen jää vain yksi pyöristetty kotipiste. |
| Unen ajoitus ilman Watchia | iPhonen Sleep-aikataulu (inBed) + latauksen ja liikkeen tila | Uni ja rytmi myös ilman wearablea (proxy, heikko) | **Uusi** |
| Päivänvalo-fallback | Askeleet auringonnousun ja klo 11:n välillä | Päivänvalo ilman Watchia (proxy) | Muutettu |
| Auringonnousu ja -lasku, aikavyöhyke | Lasketaan laitteella | Konteksti, matkasuodatin | Pidä |
| Mindful-minuutit | HealthKit (luku + kirjoitus) | Kertoo, tehtiinkö hengitysharjoitus | Pidä (ei pisteytetä) |

## Taso B: wearable (Watch, Oura, Garmin… HealthKitin kautta)

| Signaali | Lähde | Miksi | Muutos |
|---|---|---|---|
| Unen kesto, tehokkuus, valveilla olo, midpoint | `sleepAnalysis` | **Vahvin relapsinäyttö** (RADAR-MDD, Matcham 2024) | Pidä |
| **Unen säännöllisyys** (midpointin ja keston 7 päivän SD) | Lasketaan | Epäsäännöllisyys ennusti huonompaa kulkua | **Uusi, tärkein lisäys** |
| Leposyke | `restingHeartRate` | Autonominen tila + flunssasuodatin | Pidä |
| HRV | `heartRateVariabilitySDNN` | Haasteen nimeämä autonominen signaali | Pidä, puolipainolla. Oma baseline per lähde. |
| Hengitystiheys, rannelämpö | HealthKit | Ensisijaisesti flunssasuodatin | Pidä |
| Päivänvalominuutit (+ ennen klo 11) | `timeInDaylight` | Päivänvalo, aamuvalo-toimenpiteen vaste | Uusi jako ennen ja jälkeen klo 11 |
| Liikuntaminuutit, treenit | HealthKit | Liike, kävely-toimenpiteen vaste | Pidä |
| Univaiheet, sykkeen palautuminen | HealthKit | Heikko näyttö | Näytetään, mutta ei pisteytetä |

**Body-pisteen sisältö:** leposyke, HRV, hengitystiheys ja rannelämpö. Flunssasuodatin toimii niiden päällä.

## Taso C: vapaaehtoinen, kevyt aktiivinen mittaus

Tällä tasolla on enintään **yksi kehote päivässä**.

| Mittaus | Kuinka usein | Käyttö |
|---|---|---|
| **"Miten meni?" toimenpiteen jälkeen** | 1 napautus | Suljetun silmukan subjektiivinen puoli |
| **Pulssimittaus sormella kameralla** (60 s, salama päällä, punaisen kanavan PPG → HR ja RMSSD) | Ennen ja jälkeen hengityksen, halutessa | HRV ja vaste ilman wearablea. Haasteen nimeämä kamera ja autonominen tila, ja mittauksen voi näyttää lavalla. |
| **Äänitsekkaus** (sama lause 15 s ajan, analysoidaan laitteella: sävelkorkeuden vaihtelu, taukosuhde, puhenopeus) | Kerran viikossa, halutessa. Otetaan käyttöön onboardingissa, ei kriisihetkellä. | Haasteen nimeämä ääni. Trendi näytetään henkilölle (ja hoitajalle), mutta sitä ei pisteytetä. Ääni poistetaan heti. |
| State of Mind, PHQ-9 ja GAD-7 Healthista | Jos käyttäjä kirjaa ne itse | Näytetään vertailuna, kuten nyt |
| PHQ-2 sovelluksessa | 2 viikon välein | Ankkuri, joka kertoo, seuraako Steadiness oikeaa vointia. Korkeaan pisteeseen tarvitaan määritelty vastaus (kriisiohje). |

## Ei kerätä

- **Kalenteri** (`calendarEvents`, `eventHours`) ja **kuvagalleria** (`photosTaken`, `photosAwayFromHome`): sinun päätöksesi. Poistetaan `CalendarPhotosSource.swift` ja käyttölupatekstit `NSCalendars…` ja `NSPhotoLibrary…`.
- **Passiivinen mikrofoni, kamera tai kasvojen ilmeet, puhelu- ja viestilokit, näppäimistöanalyysi, Wi-Fi ja valmistajien pilvirajapinnat:** yksityisyyshaitta on liian suuri, ja kasvoilta tunnistaminen on EU AI Actissa korkean riskin luokkaa. Kieltäytyminen ja sen perustelu sopii pitchiin omaksi kalvokseen.
- **Screen Time ja SensorKit:** ei saatavilla personal teamilla tai ilman tutkimushyväksyntää. Rivit poistetaan Data-näkymästä, koska ne näyttävät täytteeltä.
- **Kaatumisriskiin ja kuntoon liittyvät:** kävelyn epäsymmetria, double support, askelpituus, portaat, 6 min kävely, walking steadiness, falls, VO₂max, low fitness.
- **Päällekkäiset:** syke (keski, min, max, kävely), aktiivinen ja lepoenergia, physical effort, seisominen, kerrokset, matkat, pyöräily, ajoneuvo, treenityypit ja effort.
- **Sydän- ja apneahälytykset:** korkea, matala ja epäsäännöllinen syke, SpO₂, hengityshäiriöt.
- **Ääni- ja muut ympäristösignaalit:** ympäristön ja kuulokkeiden äänitaso, kovat äänet, AirPods-vaimennus, UV, vesi, yökuuntelu.
- **Muut:** käsienpesu, hampaidenpesu, paino, pituus, ikä, sukupuoli (paino voi ahdistaa).
- **Kofeiini, alkoholi ja lääkkeet:** stigma. Ks. Avoimet päätökset 3.
- **Symptom-kirjaukset:** harvoin käytössä. Väsymys ja päänsärky voisi pitää flunssasuodattimen syötteinä.

## Suljettu silmukka: mikä toimii juuri tälle ihmiselle

Nykyinen sääntö ("auttoi, jos Steadiness palaa 7 päivässä") mittaa lähinnä regressiota keskiarvoon. Uudessa mallissa jokaisella toimenpiteellä on **nopea vaste** ja **seuraavan yön vaste**, ja niitä verrataan ihmisen omiin drift-päiviin, joina toimenpidettä ei tehty. Toimenpiteen voi aloittaa minä päivänä tahansa ("Kokeile yhtä"), jolloin dataa kertyy nopeammin. Tuloksia laskemalla saadaan järjestys, eikä tähän tarvita koneoppimista.

| Toimenpide | Nopea vaste | Seuraava yö / viikko |
|---|---|---|
| Hidas hengitys | RMSSD ja syke sessiossa vs. sitä ennen (Watch tai kamerapulssi) + "Miten meni?" | Nukahtaminen, valveilla olo |
| Aamuvalo | Päivänvalo ennen klo 11:tä (tai askel-fallback) | Midpointin siirtymä ja sen SD |
| Lyhyt kävely | Askeleet tai treeni ikkunassa, paikat | Unen tehokkuus, aamun leposyke |

Käyttäjälle näkyy esimerkiksi: "Sykkeesi hidastui 6 bpm neljässä viidestä kerrasta."

## Mitä lähtee puhelimesta

- **Oletuksena ei mitään.** Lähettäminen alkaa vasta, kun puhelin on paritettu klinikan kanssa QR-koodilla.
- **Sisältö:** askel, Steadiness, valmiista pohjasta tehty yksirivinen syy ilman sijaintia sekä kokeillut toimenpiteet ja tieto siitä, auttoivatko ne.
- **Ennen eskalaatiota** käyttäjä näkee tarkalleen, mitä lähtee, ja valitsee "Lähetä" tai "Ei nyt". Ystävän viestin lähettää aina käyttäjä itse.
- **Ilmoitukset lukitusnäytöllä ovat neutraaleja,** esimerkiksi "Usualilla on ehdotus".
- **Kriisiohje (112) näkyy** onboardingissa ja jokaisella askeleella.
- **Sovellus kuvataan rehellisesti:** "tutkimusprototyyppi, ei lääkinnällinen laite".

## Avoimet päätökset sinulle

1. **Sijainti:** pidetäänkö se ytimessä (vahvin näyttö) vai siirretäänkö opt-iniksi (yksityisyyskriitikon suositus: "Always"-lupa tuntuu valvonnalta)? *Suositus: pidetään ytimessä, mutta Steadiness toimii myös ilman sitä, ja lupaa pyydetään erikseen perustelun kanssa.*
2. **Henkilökohtainen painotus:** kun PHQ-2-vastauksia on kertynyt noin 4, painotetaanko niitä pisteitä, joiden lasku edelsi tämän ihmisen huonompia vastauksia? Tämä on vahva "learns what works" -argumentti, mutta se tarkoittaa, että itseraportti vaikuttaa laskentaan epäsuorasti.
3. **Kofeiini, alkoholi ja lääkkeet:** pudotetaanko kokonaan (tuomarin suositus) vai pidetäänkö lääkkeet opt-inina, joka näytetään mutta jota ei lähetetä (yksityisyyskriitikon suositus)?
4. **Mitä C-tasosta rakennetaan demoon?** *Suositus: ensin "Miten meni?" ja kamerapulssi, sitten äänitsekkaus, viimeisenä PHQ-2.*

## Tarkistettavat faktat ennen pitchiä

- **HealthKitin background delivery:** toimiiko entitlement ilmaisella personal teamilla? Jos ei, käytetään fallbackina `BGAppRefreshTask`ia ja päivitystä sovelluksen avautuessa.
- **Ouran ja WHOOPin HRV:** kirjoittavatko ne HRV:n `SDNN`-tyyppiin, ja onko arvo silloin oikeasti RMSSD-tyyppinen?
- **Datatiedostojen suojaus:** käytetään `completeUntilFirstUserAuthentication`, ei `complete`. Muuten yöllinen laskenta lukitulla laitteella epäonnistuu.
- **Lähdeviitteet:** Stamatis 2024, Matcham 2024, Hernandez 2025 ja Zhang 2022 tarkistetaan alkuperäisistä.

## Beside demo scope update, 14 November 2026

The user explicitly requested the following additions for the demo: logged dietary energy, water, protein, carbohydrates and total fat, plus existing State of Mind, mindful minutes and PHQ-9/GAD-7 results. The active interface requests these read-only and displays them as context, separated from scoring and automatic contact rules. Missing records remain unknown; no meal count or diagnosis is inferred. The exact active read allow-list is documented in HEALTHKIT_DATA.md. This update supersedes earlier exclusions only for these explicitly named types.
