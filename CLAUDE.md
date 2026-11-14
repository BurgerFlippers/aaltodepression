# Työskentelysäännöt: backend ja frontend rinnakkain

Tätä repoa kehittää samaan aikaan useampi ihminen ja heidän Claude-sessionsa. Nämä säännöt ovat olemassa, jotta muutokset eivät törmää toisiinsa. Noudata niitä jokaisessa sessiossa.

Mitä rakennetaan: [docs/APP_DESIGN.md](docs/APP_DESIGN.md). Mitä dataa saa kerätä: [docs/DATA_SCOPE.md](docs/DATA_SCOPE.md). Miten frontend käyttää backendia: [docs/BACKEND_API.md](docs/BACKEND_API.md).

## 1. Kuka omistaa mitäkin

Kysy käyttäjältä aina session alussa, onko hän **backend** vai **frontend**, ellei hän ole jo kertonut. Muokkaa sen jälkeen vain oman alueesi tiedostoja.

| Alue | Omistaja | Polut |
|---|---|---|
| Logiikka ja data | **backend** | `aaltodepression/Engine/**`, `aaltodepression/Sources/**`, `aaltodepression/Store/**`, `aaltodepression/Resources/*.json`, `Tools/**` |
| Näkymät | **frontend** | `aaltodepression/UI/**`, `aaltodepression/Features/**`, `aaltodepression/Assets.xcassets/**` |
| Sopimus (rajapinta) | **backend** kirjoittaa, frontend lukee | `aaltodepression/Engine/Contracts/**` |
| Väliaikaiset testinäkymät | **backend**, poistetaan kun oikeat näkymät ovat valmiit | `aaltodepression/DevTools/**` (avataan Settingsin "Backend testing" -rivistä) |
| Kuumat tiedostot | **vain sovitusti**, yksi kerrallaan | `aaltodepression/AppModel.swift`, `aaltodepression/UsualApp.swift`, `aaltodepression.xcodeproj/**`, `Config/**` |
| Dokumentit | kuka tahansa, vain oma osio | `docs/**`, `README.md`, `CLAUDE.md` |

Tämä jako korvaa [docs/APP_DESIGN.md](docs/APP_DESIGN.md):n tiedostorakenteen siltä osin, että **logiikka ei asu `Features/`-kansiossa**:

- Logiikka, säännöt ja mallit kuuluvat backendille, esimerkiksi `Engine/Food/FoodPlanner.swift` ja `Engine/Safety/SafetyFlow.swift`.
- `Features/<Ominaisuus>/` sisältää vain SwiftUI-näkymät ja niiden paikallisen tilan, esimerkiksi `Features/Food/ShoppingListView.swift`.

Jos tarvitset muutoksen toisen alueen tiedostoon, **älä tee sitä**. Kerro käyttäjälle, mitä tarvitset ja miksi, ja lisää pyyntö tiedostoon [docs/HANDOFF.md](docs/HANDOFF.md) (ks. kohta 5).

## 2. Sopimus ensin

Backend ja frontend kohtaavat vain kansiossa `Engine/Contracts/`. Siellä ovat tyypit, joita näkymät näyttävät, kuten `TodayPlan`, `PlanItem`, `CheckIn`, `Capacity`, `SupportSuggestion`, `SafetyStep` ja `WeaveDay`, sekä protokollat palveluille, joita näkymät kutsuvat.

- **Muutokset ovat vain lisäyksiä.** Uusi kenttä saa oletusarvon, eikä kenttiä tai tyyppejä nimetä uudelleen eikä poisteta ilman käyttäjien sopimusta.
- **Frontend ei odota backendia.** Se tekee näkymät `Engine/Contracts/`-tyyppien varaan ja käyttää esimerkkidataa tiedostosta `Features/Previews/SampleData.swift`, joka on frontendin oma tiedosto.
- **Backend ei koske näkymiin.** Kun logiikka on valmis, backend kertoo sen tiedostossa `docs/HANDOFF.md`, ja frontend kytkee sen.

## 3. Kuumat tiedostot

Näihin syntyy konflikteja helpoimmin. Muokkaa niitä vain, kun käyttäjä on sopinut asiasta tiimin kanssa, ja pidä muutos pienenä.

- **`AppModel.swift`:** älä kasvata sitä.
  - Backendin palvelut menevät omiin tiedostoihinsa laajennoksina, esimerkiksi `Store/AppModel+Meds.swift`.
  - Frontendin näkymätila menee näkymäkohtaisiin `@Observable`-malleihin, esimerkiksi `Features/Today/TodayModel.swift`.
  - Varsinaista `AppModel.swift`-tiedostoa muokkaa vain se, joka kytkee osat yhteen.
- **`UsualApp.swift`:** välilehtirakennetta muokkaa vain frontend, ilmoitusten delegaattia vain backend. Älä koske toisen osuuteen.
- **`project.pbxproj`:** Xcode-projekti käyttää synkronoituja kansioita, joten **uuden tiedoston lisääminen ei muuta `project.pbxproj`:ia**. Luo tiedostot suoraan oikeaan kansioon. Älä lisää tiedostoja Xcoden kautta tavalla, joka muuttaa projektitiedostoa.
- **Allekirjoitus:** **älä koskaan commitoi omia `DEVELOPMENT_TEAM`- tai `PRODUCT_BUNDLE_IDENTIFIER`-muutoksiasi.** Jokaisen personal team muuttaa nämä paikallisesti. Ennen commitia tarkista `git diff --cached aaltodepression.xcodeproj`, ja jos siinä on vain tiimi- tai bundle id -rivejä, poista ne commitista: `git restore --staged aaltodepression.xcodeproj/project.pbxproj`.
- **`Config/Info.plist`, `Config/App.entitlements`:** uudet lupatekstit ja capabilityt sovitaan ensin. Lupatekstit ovat englanniksi ja kuvaavat rehellisesti, mitä dataa käytetään.

## 4. Git-käytäntö

1. **Session alussa:** `git fetch` ja `git status`. Jos olet `main`-haarassa, luo oma haara: `backend/<aihe>` tai `frontend/<aihe>`.
2. **Pienet commitit, usein.** Yksi asia per commit. Viestin alkuun `[backend]` tai `[frontend]`.
3. **Pysy ajan tasalla:** `git pull --rebase origin main` ennen jokaista pushia ja vähintään tunnin välein.
4. **Lisää tiedostot nimeltä,** ei `git add -A` tai `git add .`. Varmista `git diff --cached --stat`, että mukana on vain oman alueen tiedostoja.
5. **Älä commitoi:** `xcuserdata/`, `build/`, `*.xcuserstate` tai omaa allekirjoitusta.
6. **Ei massamuutoksia:** älä aja formatteria koko repoon, älä järjestä importteja, äläkä nimeä tai siirrä tiedostoja toisen alueella.
7. **Konfliktissa:** älä ratkaise toisen alueen tiedoston konfliktia arvaamalla. Pysähdy ja kerro käyttäjälle.
8. **Mergeä mainiin vasta, kun build menee läpi** (kohta 6). Pushaa vain, kun käyttäjä pyytää.

## 5. Viestintä: docs/HANDOFF.md

Tiedosto `docs/HANDOFF.md` on yhteinen ilmoitustaulu. Jokainen lisää vain uusia rivejä tiedoston loppuun eikä muokkaa muiden rivejä, jolloin konflikteja ei synny. Lisää rivi, kun

- sopimukseen (`Engine/Contracts/`) tuli uusi tyyppi tai kenttä
- jokin logiikka on valmis kytkettäväksi
- tarvitset muutoksen toisen alueen tiedostoon

Muoto: `- [backend] 14:20 TodayBuilder.build(...) valmis, palauttaa TodayPlan. Kytke Features/Today/TodayView.swift.`

## 6. Tarkistus ennen committia

Molemmat alueet: projekti kääntyy simulaattorille ilman allekirjoitusta.

```bash
xcodebuild -project aaltodepression.xcodeproj -scheme aaltodepression -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO -quiet
```

Backend lisäksi: moottorin tarkistus menee läpi. Se kääntää kaikki `Engine/`-tiedostot ja `Sources/DemoSource.swift`-tiedoston ilman SwiftUI:ta, joten **`Engine/`-tiedostot eivät saa importata SwiftUI:ta tai UIKitiä**.

```bash
Tools/engine-check.sh
```

## 7. Tekniset perusasiat

- Swift 6 ja SwiftUI, minimi iOS 17. Uudemmat rajapinnat `#available`-tarkistuksen taakse.
- **Ilmainen personal team:** ei push-ilmoituksia, WeatherKitiä eikä tekstiviestipalvelinta. Läheisen viestit ovat demossa simuloituja.
- **Turvallisuustekstit** (`Engine/Planner/SafetyFlow.swift`, `SafetyCopy`) ovat lääkärin tarkistettavia työversioita. Muuta niitä vain, kun käyttäjä pyytää.
- **Kaikki sovelluksessa on englanniksi:** näkyvä teksti, viestipohjat, turvallisuustekstit, koodi, tunnisteet ja kommentit.
