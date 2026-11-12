// Diapositives de détail : modèles, Pydantic, rappel, git. Appelées par build.js.
module.exports = (ctx) => {
  const { pres, C, THEME, MONO, content, divider, sec, T, box, dot, num, card, arrow, bullets } = ctx;
  let n = 1000;
  const line = (s, x, y, w, h, color = C.accent4, width = 3) =>
    s.addShape(pres.shapes.LINE, { x, y, w, h, line: { color, width }, objectName: "trait " + (++n) });
  const node = (s, x, y, color, d = 0.5) =>
    s.addShape(pres.shapes.OVAL, { x: x - d / 2, y: y - d / 2, w: d, h: d, fill: { color }, line: { color: C.background1, width: 2 }, objectName: "commit " + (++n) });
  const pill = (s, x, y, w, text, color, size = 14) => {
    box(s, x, y, w, 0.45, color);
    T(s, text, { x, y, w, h: 0.45, align: "center", valign: "middle", fontFace: MONO, fontSize: size, bold: true, color: C.background1 });
  };
  // Bloc de code sombre : lignes [texte, couleur hex facultative].
  const code = (s, x, y, w, h, lines, size = 15) => {
    box(s, x, y, w, h, C.text1);
    T(s, lines.map(([t, color, bold], i) => ({ text: t === "" ? " " : t, options: { breakLine: i < lines.length - 1, color: color || C.background1, bold: !!bold } })),
      { x: x + 0.3, y: y + 0.25, w: w - 0.6, h: h - 0.5, fontFace: MONO, fontSize: size, paraSpaceAfter: 5 });
  };
  const ROUGE = "FCA5A5", VERT = "86EFAC", GRIS = "94A3B8";

  const modeles = async () => {
    sec("Les modèles en détail");
    divider("Les modèles, en détail", "Un fichier, un logiciel, six tailles, trois familles à comparer", "Section de détail, à utiliser pendant l'étape 1 avec l'équipe 2, puis au début de l'étape 2 avant de lancer les comparaisons.");
    {
      const s = content("Qui parle à qui", "Quatre couches. L'application ne connaît que la passerelle ; la passerelle ne connaît que le nom med-extraction ; le runtime charge le fichier. Conséquence : on change le fichier tout en bas, rien ne bouge au-dessus. C'est ce qui permet de comparer des modèles sans toucher à l'application.");
      const bands = [[C.accent1, "L'application", "demande « med-extraction »"], [C.accent5, "La passerelle", "distribue, bascule, mesure"], [C.accent3, "Le runtime", "Ollama · llama.cpp"], [C.text1, "Le modèle", "un fichier .gguf"]];
      bands.forEach(([color, head, sub], i) => {
        const y = 1.8 + i * 1.2;
        box(s, 0.7, y, 6.6, 0.95, color);
        T(s, head, { x: 1.0, y, w: 2.8, h: 0.95, fontSize: 22, bold: true, valign: "middle", color: C.background1 });
        T(s, sub, { x: 3.8, y, w: 3.3, h: 0.95, fontSize: 15, valign: "middle", color: C.background1 });
        if (i < 3) arrow(s, 4.0, y + 0.97, 0, 0.21);
      });
      T(s, "Chaque couche ne connaît que celle du dessous.", { x: 7.9, y: 2.0, w: 4.7, h: 1.3, fontSize: 26, bold: true, color: C.accent1 });
      T(s, "On remplace le fichier tout en bas : rien ne bouge au-dessus. C'est ce qui permet de comparer des modèles sans toucher à l'application.", { x: 7.9, y: 3.6, w: 4.7, h: 2.2, fontSize: 18 });
    }
    {
      const s = content("Lire le nom d'un modèle", "Décortiquer un nom de fichier. La quantification est une compression : chaque paramètre est stocké sur 4 bits au lieu de 16, le fichier est environ quatre fois plus petit, au prix d'une légère perte de précision. Sans elle, aucun de ces modèles ne tiendrait sur un portable.");
      const parts = [["Qwen3.5", C.accent1, "La famille et la version", "Qui l'a entraîné, et quelle génération."], ["4B", C.accent5, "La taille", "4 milliards de paramètres : plus il y en a, plus le modèle est capable, lourd et lent."], ["Q4_K_M", C.accent3, "La compression", "Quantification : 4 bits par paramètre. Un fichier quatre fois plus petit, un peu moins précis."], [".gguf", C.accent4, "Le format", "Celui que lisent Ollama et llama.cpp : le même fichier pour les deux."]];
      parts.forEach(([txt, color, head, body], i) => {
        const x = 0.7 + i * 3.03;
        box(s, x, 1.8, 2.8, 1.0, color);
        T(s, txt, { x, y: 1.8, w: 2.8, h: 1.0, align: "center", valign: "middle", fontFace: MONO, fontSize: 26, bold: true, color: C.background1 });
        box(s, x, 3.05, 2.8, 3.4);
        T(s, head, { x: x + 0.25, y: 3.3, w: 2.3, h: 0.8, fontSize: 19, bold: true });
        T(s, body, { x: x + 0.25, y: 4.15, w: 2.3, h: 2.1, fontSize: 15 });
      });
    }
    {
      const s = content("Six modèles, selon la machine", "Les six modèles du projet, du plus léger au plus lourd. La règle pratique : le fichier doit tenir en mémoire avec de la marge. Chacun prend le plus grand que sa machine supporte, et l'écrit dans la fiche de son poste. Les tailles sont approximatives.");
      s.addChart(pres.charts.BAR, [{ name: "Taille du fichier (Go)", labels: ["Ornith-1.5-35B-A3B", "Ornith-1.5-9B", "Gemma 4 E4B", "MedGemma 4B", "Qwen3.5-4B", "Qwen3.5-2B"], values: [22, 6.5, 5.4, 3, 3, 1.2] }], {
        x: 0.6, y: 1.7, w: 7.6, h: 4.9, barDir: "bar", chartColors: [THEME.colors.accent1], showTitle: true, title: "Taille du fichier, en Go (environ)", titleFontSize: 14, titleFontFace: "+mn-lt", titleColor: THEME.colors.dk2,
        showValue: true, dataLabelFormatCode: "0.0", dataLabelPosition: "outEnd", dataLabelFontSize: 13, dataLabelFontFace: "+mn-lt", dataLabelColor: THEME.colors.dk1,
        catAxisLabelFontSize: 13, catAxisLabelFontFace: "+mn-lt", catAxisLabelColor: THEME.colors.dk1, valAxisHidden: true, valGridLine: { style: "none" }, catGridLine: { style: "none" }, showLegend: false, objectName: "graphique tailles",
      });
      const tiers = [["8 Go de mémoire", "un modèle 4B"], ["16 Go", "Ornith-1.5-9B"], ["Carte graphique de 24 Go", "Ornith-1.5-35B-A3B"]];
      tiers.forEach(([h, b], i) => {
        const y = 1.9 + i * 1.5;
        box(s, 8.6, y, 4.0, 1.25);
        T(s, h, { x: 8.85, y: y + 0.15, w: 3.5, h: 0.45, fontSize: 15, color: C.accent4 });
        T(s, b, { x: 8.85, y: y + 0.6, w: 3.5, h: 0.5, fontSize: 19, bold: true });
      });
    }
    {
      const s = content("Trois modèles 4B, une question", "Le cœur de la comparaison. Même gabarit, trois origines. Deux généralistes de familles différentes et un modèle entraîné sur des textes médicaux. Faire parier la salle avant de lancer : lequel extraira le mieux ? Rappeler que MedGemma n'est pas un dispositif médical et que ses conditions d'usage sont plus restrictives.");
      const m = [["FaGlobeEurope", C.accent1, "Qwen3.5-4B", "Généraliste", "La famille dont Ornith est issu, une taille en dessous."], ["FaGlobeEurope", C.accent5, "Gemma 4 E4B", "Généraliste", "Une autre famille, un autre entraînement, le même gabarit."], ["FaStethoscope", C.accent6, "MedGemma 4B", "Spécialisé médecine", "Entraîné sur des textes médicaux. Conditions d'usage plus restrictives."]];
      for (let i = 0; i < 3; i++) {
        const [ic, color, head, kind, body] = m[i]; const x = 0.7 + i * 4.05;
        box(s, x, 1.8, 3.8, 3.2);
        await dot(s, x + 0.3, 2.05, 0.8, color, ic);
        T(s, head, { x: x + 1.3, y: 2.05, w: 2.3, h: 0.45, fontSize: 20, bold: true });
        T(s, kind, { x: x + 1.3, y: 2.5, w: 2.3, h: 0.4, fontSize: 14, color: C.accent4 });
        T(s, body, { x: x + 0.3, y: 3.2, w: 3.2, h: 1.6, fontSize: 15 });
      }
      box(s, 0.7, 5.3, 11.9, 1.2, C.text1);
      T(s, "Un modèle entraîné sur la médecine extrait-il mieux ? C'est le score qui répond, pas l'intuition.", { x: 1.0, y: 5.3, w: 11.3, h: 1.2, fontSize: 21, bold: true, valign: "middle", color: C.background1 });
    }
    {
      const s = content("Quatre façons d'être un modèle", "Le vocabulaire qu'on croise en lisant une fiche de modèle. Un mélange d'experts contient beaucoup de paramètres mais n'en active qu'une partie à chaque mot : il demande la mémoire d'un gros modèle et répond à la vitesse d'un petit. Un modèle à raisonnement écrit d'abord un brouillon de réflexion : meilleur sur les cas difficiles, plus lent.");
      const k = [["FaGlobeEurope", "Généraliste", "Entraîné sur de tout. Qwen3.5, Gemma 4."], ["FaStethoscope", "Spécialisé", "Réentraîné sur un domaine. MedGemma : la médecine."], ["FaLightbulb", "À raisonnement", "Réfléchit avant de répondre : plus juste sur les cas difficiles, plus lent. Ornith."], ["FaProjectDiagram", "Mélange d'experts", "Ornith-1.5-35B-A3B : 35 milliards de paramètres, 3 milliards actifs à chaque mot."]];
      for (let i = 0; i < 4; i++) await card(s, 0.7 + (i % 2) * 6.05, 1.8 + Math.floor(i / 2) * 2.4, 5.85, 2.15, { ic: k[i][0], color: C.accent1, head: k[i][1], body: k[i][2], bodySize: 16 });
    }
    {
      const s = content("Comparer honnêtement", "Le protocole. Une seule chose change entre deux essais : le modèle. Mêmes dossiers, même consigne, même référence, même machine. Le nom donné à --run est celui qui apparaîtra dans le classement.");
      const st = [["Importer le modèle A", "02-inference/ollama/create-model.sh qwen4b"], ["Extraire", "./bin/farci extract --subset quick --run qwen4b"], ["Importer le modèle B", "02-inference/ollama/create-model.sh medgemma4b"], ["Extraire", "./bin/farci extract --subset quick --run medgemma4b"], ["Classer", "./bin/farci evaluate --subset quick"]];
      st.forEach(([h, c], i) => {
        const y = 1.75 + i * 0.83;
        num(s, 0.7, y + 0.03, 0.62, i === 4 ? C.accent2 : C.accent1, i + 1);
        T(s, h, { x: 1.6, y, w: 3.4, h: 0.68, fontSize: 18, bold: true, valign: "middle" });
        box(s, 5.1, y, 7.5, 0.68, C.text1);
        T(s, c, { x: 5.35, y, w: 7.1, h: 0.68, fontFace: MONO, fontSize: 14, valign: "middle", color: C.background1 });
      });
      T(s, "Une seule chose change : le modèle. Mêmes dossiers, même consigne, même référence.", { x: 0.7, y: 6.0, w: 11.9, h: 0.6, fontSize: 18, italic: true, color: C.text2 });
    }
  };

  const mesurer = async () => {
    sec("Valider, puis mesurer");
    divider("Valider, puis mesurer", "Pydantic refuse ce qui est mal formé ; le rappel, votre sensibilité, dit ce qui a été manqué", "Deux contrôles différents, souvent confondus. Pydantic vérifie la forme de la réponse. L'évaluation contre le gold standard vérifie le fond.");
    {
      const s = content("Pydantic : le formulaire, écrit en Python", "Pydantic est la bibliothèque Python qui décrit le formulaire et contrôle chaque réponse. C'est un extrait du vrai fichier du projet, 07-applications/common/schemas.py. Chaque champ a un type, parfois des bornes ou une liste de valeurs permises. Optional ne veut pas dire facultatif : le champ doit être présent, mais peut valoir null, c'est-à-dire non précisé dans le compte rendu.");
      code(s, 0.7, 1.8, 7.3, 4.7, [
        ["class ClinicalExtraction(BaseModel):", VERT, true], [""],
        ["  age: int = Field(ge=0, le=120)"],
        ['  sex: str = Field(pattern="^(M|F)$")'],
        ["  pT: Optional[str] = Field("],
        ['      pattern="^(pT1|pT2|pT3|pT4)$")'],
        ["  pancreatic_fistula: bool"],
        ["  length_of_stay: int = Field(ge=0)"], [""],
        ["# 07-applications/common/schemas.py", GRIS],
      ], 14);
      const a = [["Un type par champ", "nombre, texte, oui ou non"], ["Des bornes", "un âge entre 0 et 120"], ["Des valeurs permises", "pT1, pT2, pT3 ou pT4, rien d'autre"], ["Optional", "le champ est exigé, mais peut valoir « non précisé »"]];
      a.forEach(([h, b], i) => {
        const y = 1.85 + i * 1.18;
        num(s, 8.4, y, 0.55, C.accent1, i + 1);
        T(s, h, { x: 9.15, y: y - 0.05, w: 3.5, h: 0.4, fontSize: 18, bold: true });
        T(s, b, { x: 9.15, y: y + 0.38, w: 3.5, h: 0.6, fontSize: 14, color: C.text2 });
      });
    }
    {
      const s = content("Ce que Pydantic refuse", "Quatre réponses de modèle refusées, avec le message exact de Pydantic, et une acceptée. Une seule erreur suffit : toute la réponse est rejetée et rien n'est écrit. La dernière ligne est importante : null est une vraie réponse. Un modèle qui dit non précisé quand le compte rendu ne le dit pas a raison.");
      const rows = [["age: \"soixante-sept ans\"", "Input should be a valid integer", false], ["age: 167", "Input should be less than or equal to 120", false], ["pT: \"T3\"", "String should match pattern '^(pT1|pT2|pT3|pT4)$'", false], ["margin_R  (champ absent)", "Field required", false], ["margin_R: null", "Accepté : « non précisé » est une réponse", true]];
      T(s, "Ce que renvoie le modèle", { x: 1.6, y: 1.65, w: 4.2, h: 0.4, fontSize: 14, color: C.accent4 });
      T(s, "Ce que répond Pydantic", { x: 6.1, y: 1.65, w: 6.4, h: 0.4, fontSize: 14, color: C.accent4 });
      for (let i = 0; i < rows.length; i++) {
        const [l, r, okk] = rows[i]; const y = 2.1 + i * 0.9;
        box(s, 0.7, y, 11.9, 0.75);
        await dot(s, 0.85, y + 0.1, 0.55, okk ? C.accent2 : C.accent6, okk ? "FaCheck" : "FaTimes");
        T(s, l, { x: 1.6, y, w: 4.3, h: 0.75, fontFace: MONO, fontSize: 14, valign: "middle" });
        T(s, r, { x: 6.1, y, w: 6.4, h: 0.75, fontFace: okk ? undefined : MONO, fontSize: 14, valign: "middle", color: okk ? C.accent2 : C.accent6, bold: okk });
      }
    }
    {
      const s = content("Bien formé ne veut pas dire juste", "La charnière entre les deux contrôles. Pydantic accepte un âge de 76 ans : c'est un nombre entre 0 et 120. Mais le patient en a 67. Seule la comparaison au gold standard le voit. D'où la suite : mesurer.");
      box(s, 0.7, 1.8, 5.8, 3.3);
      await dot(s, 1.0, 2.05, 0.8, C.accent1, "FaClipboardCheck");
      T(s, "Pydantic vérifie la forme", { x: 2.05, y: 2.05, w: 4.2, h: 0.8, fontSize: 21, bold: true, valign: "middle" });
      T(s, "L'âge est-il un nombre, entre 0 et 120 ?", { x: 1.0, y: 3.15, w: 5.2, h: 0.8, fontSize: 17 });
      T(s, "age: 76   → accepté", { x: 1.0, y: 4.1, w: 5.2, h: 0.5, fontFace: MONO, fontSize: 16, color: C.accent2, bold: true });
      box(s, 6.8, 1.8, 5.8, 3.3);
      await dot(s, 7.1, 2.05, 0.8, C.accent3, "FaBalanceScale");
      T(s, "La référence vérifie le fond", { x: 8.15, y: 2.05, w: 4.2, h: 0.8, fontSize: 21, bold: true, valign: "middle" });
      T(s, "L'âge est-il celui du patient ?", { x: 7.1, y: 3.15, w: 5.2, h: 0.8, fontSize: 17 });
      T(s, "age: 76   → faux (67 attendu)", { x: 7.1, y: 4.1, w: 5.2, h: 0.5, fontFace: MONO, fontSize: 16, color: C.accent6, bold: true });
      box(s, 0.7, 5.4, 11.9, 1.1, C.text1);
      T(s, "Il faut les deux : un formulaire qui refuse le mal formé, et une mesure qui repère le faux.", { x: 1.0, y: 5.4, w: 11.3, h: 1.1, fontSize: 19, bold: true, valign: "middle", color: C.background1 });
    }
    {
      const s = content("Quatre issues pour chaque champ", "Pour chaque champ de chaque dossier, on compare la réponse du modèle à la référence. Quatre issues. Trouvé : la bonne valeur. Manqué : il y avait une valeur, le modèle a répondu non précisé. Inventé : il n'y avait rien, le modèle a donné une valeur. Faux : une mauvaise valeur, qui compte à la fois comme manquée et comme inventée.");
      const heads = ["Champ", "La référence", "Le modèle", "Issue"];
      const xs = [0.7, 3.3, 6.0, 8.7], ws = [2.5, 2.6, 2.6, 3.9];
      heads.forEach((h, i) => T(s, h, { x: xs[i] + 0.2, y: 1.7, w: ws[i], h: 0.4, fontSize: 14, color: C.accent4 }));
      const rows = [["Stade pT", "pT3", "pT3", "Trouvé", C.accent2], ["Marge d'exérèse", "R0", "non précisé", "Manqué", C.accent3], ["Taille de la tumeur", "non précisée", "28 mm", "Inventé", C.accent6], ["Stade pN", "pN1", "pN2", "Faux : manqué et inventé", C.accent6]];
      rows.forEach((r, i) => {
        const y = 2.15 + i * 0.95;
        box(s, 0.7, y, 7.8, 0.8);
        for (let c = 0; c < 3; c++) T(s, r[c], { x: xs[c] + 0.2, y, w: ws[c] - 0.2, h: 0.8, fontSize: 17, valign: "middle", bold: c === 0 });
        box(s, 8.7, y, 3.9, 0.8, r[4]);
        T(s, r[3], { x: 8.7, y, w: 3.9, h: 0.8, fontSize: 17, bold: true, align: "center", valign: "middle", color: C.background1 });
      });
      T(s, "Et quand il n'y avait rien à trouver et que le modèle répond « non précisé » : il a raison.", { x: 0.7, y: 6.15, w: 11.9, h: 0.5, fontSize: 16, italic: true, color: C.text2 });
    }
    {
      const s = content("Le rappel : ce qu'il fallait trouver", "Faire le calcul avec la salle. Dix-huit valeurs à trouver dans le dossier. Le modèle en trouve quinze, en manque deux, se trompe sur une. Rappel : quinze sur dix-huit. Précision : parmi ses seize réponses, quinze justes. Un modèle prudent qui se tait a une bonne précision et un mauvais rappel ; un modèle bavard, l'inverse.");
      T(s, "18 valeurs à trouver. Le modèle en trouve 15, en manque 2, se trompe sur 1.", { x: 0.7, y: 1.7, w: 11.9, h: 0.6, fontSize: 19 });
      const st = [["83 %", "Rappel", "15 trouvées sur 18 à trouver", "trouvées ÷ (trouvées + manquées + fausses)", C.accent3], ["94 %", "Précision", "15 justes sur 16 réponses données", "trouvées ÷ (trouvées + inventées + fausses)", C.accent2]];
      st.forEach(([v, l, d, f, color], i) => {
        const x = 0.7 + i * 6.05;
        box(s, x, 2.55, 5.85, 3.3);
        T(s, v, { x: x + 0.3, y: 2.7, w: 2.9, h: 1.3, fontSize: 66, bold: true, color, valign: "middle" });
        T(s, l, { x: x + 3.2, y: 2.9, w: 2.5, h: 0.5, fontSize: 22, bold: true });
        T(s, d, { x: x + 3.2, y: 3.4, w: 2.5, h: 0.7, fontSize: 14, color: C.accent4 });
        T(s, f, { x: x + 0.3, y: 4.55, w: 5.3, h: 0.9, fontSize: 15, italic: true, color: C.text2 });
      });
      T(s, "Un modèle qui se tait a un bon score de précision et un mauvais rappel. Un modèle bavard, l'inverse.", { x: 0.7, y: 6.05, w: 11.9, h: 0.6, fontSize: 17, italic: true, color: C.text2 });
    }
    {
      const s = content("Vous connaissez déjà ces mesures", "Le pont avec la médecine. Le rappel est exactement la sensibilité d'un test : parmi ce qu'il fallait trouver, quelle part a été trouvée. La précision est exactement la valeur prédictive positive : quand le modèle donne une valeur, quelle est la probabilité qu'elle soit juste. Seul le vocabulaire change. Le classement du projet affiche précision et rappel ; la spécificité et la valeur prédictive négative se calculent à partir des mêmes quatre cases.");
      T(s, "En informatique", { x: 0.9, y: 1.7, w: 3.4, h: 0.4, fontSize: 14, color: C.accent4 });
      T(s, "En médecine", { x: 4.5, y: 1.7, w: 3.4, h: 0.4, fontSize: 14, color: C.accent4 });
      T(s, "La question posée", { x: 8.1, y: 1.7, w: 4.4, h: 0.4, fontSize: 14, color: C.accent4 });
      const rows = [["Rappel", "Sensibilité", "Parmi les valeurs à trouver, combien le modèle en a-t-il trouvé ?", C.accent3], ["Précision", "Valeur prédictive positive", "Quand le modèle donne une valeur, est-elle juste ?", C.accent2], ["(rarement nommée)", "Spécificité", "Quand il n'y avait rien à trouver, le modèle s'est-il abstenu ?", C.accent4], ["(rarement nommée)", "Valeur prédictive négative", "Quand le modèle dit « non précisé », n'y avait-il vraiment rien ?", C.accent1]];
      rows.forEach(([a, b, c, color], i) => {
        const y = 2.15 + i * 1.05;
        box(s, 0.7, y, 11.9, 0.9);
        box(s, 0.7, y, 3.5, 0.9, color);
        T(s, a, { x: 0.7, y, w: 3.5, h: 0.9, fontSize: i < 2 ? 21 : 15, bold: i < 2, italic: i >= 2, align: "center", valign: "middle", color: C.background1 });
        T(s, "=", { x: 4.2, y, w: 0.4, h: 0.9, fontSize: 22, bold: true, align: "center", valign: "middle", color: C.accent4 });
        T(s, b, { x: 4.6, y, w: 3.3, h: 0.9, fontSize: 18, bold: true, valign: "middle" });
        T(s, c, { x: 8.1, y, w: 4.3, h: 0.9, fontSize: 14, valign: "middle" });
      });
    }
    {
      const s = content("Le tableau de contingence d'une extraction", "Le tableau à quatre cases, celui des tests diagnostiques. En colonnes, la référence : le compte rendu contenait-il la valeur ? En lignes, le modèle : a-t-il donné une valeur ? Vrai positif : trouvé. Faux positif : inventé. Faux négatif : manqué. Vrai négatif : non précisé, à raison. Exemple sur cent champs. Une valeur fausse, non montrée ici, compte à la fois comme inventée et comme manquée.");
      T(s, "La référence : la valeur est dans le compte rendu", { x: 3.5, y: 1.65, w: 5.6, h: 0.4, fontSize: 14, align: "center", color: C.accent4 });
      [["oui", 3.5], ["non", 6.35]].forEach(([t, x]) => T(s, t, { x, y: 2.05, w: 2.75, h: 0.4, fontSize: 16, bold: true, align: "center" }));
      [["Le modèle donne une valeur", 2.5], ["Le modèle répond « non précisé »", 3.95]].forEach(([t, y]) => T(s, t, { x: 0.7, y, w: 2.65, h: 1.3, fontSize: 15, bold: true, valign: "middle" }));
      const cells = [[3.5, 2.5, C.accent2, "72", "trouvées", "vrais positifs"], [6.35, 2.5, C.accent6, "3", "inventées", "faux positifs"], [3.5, 3.95, C.accent3, "8", "manquées", "faux négatifs"], [6.35, 3.95, C.accent4, "17", "non précisé, à raison", "vrais négatifs"]];
      cells.forEach(([x, y, color, v, l, m]) => {
        box(s, x, y, 2.75, 1.3, color);
        T(s, v, { x: x + 0.2, y, w: 0.95, h: 1.3, fontSize: 36, bold: true, valign: "middle", color: C.background1 });
        T(s, l, { x: x + 1.15, y: y + 0.2, w: 1.5, h: 0.55, fontSize: 14, bold: true, valign: "middle", color: C.background1 });
        T(s, m, { x: x + 1.15, y: y + 0.75, w: 1.5, h: 0.4, fontSize: 12, color: C.background1 });
      });
      const m = [["Rappel = sensibilité", "72 ÷ (72 + 8)", "90 %"], ["Précision = VPP", "72 ÷ (72 + 3)", "96 %"], ["Spécificité", "17 ÷ (17 + 3)", "85 %"], ["VPN", "17 ÷ (17 + 8)", "68 %"]];
      m.forEach(([h, f, v], i) => {
        const y = 1.75 + i * 0.95;
        box(s, 9.5, y, 3.1, 0.82);
        T(s, h, { x: 9.65, y: y + 0.06, w: 1.9, h: 0.38, fontSize: 14, bold: true });
        T(s, f, { x: 9.65, y: y + 0.42, w: 1.9, h: 0.34, fontSize: 12, color: C.accent4 });
        T(s, v, { x: 11.45, y, w: 1.05, h: 0.82, fontSize: 22, bold: true, align: "right", valign: "middle", color: C.accent1 });
      });
      T(s, "Sur 100 champs. Bon rappel, bonne précision, et pourtant : quand le modèle dit « non précisé », il y avait quelque chose une fois sur trois.", { x: 0.7, y: 5.65, w: 11.9, h: 0.9, fontSize: 17, italic: true, color: C.text2 });
    }
    {
      const s = content("Comme pour un dépistage, la prévalence compte", "Le raisonnement du dépistage, appliqué à l'extraction. Une complication rare : présente dans 5 % des dossiers. Le modèle est bon : sensibilité 90 %, spécificité 95 %. Sur mille dossiers, 50 ont la complication, il en trouve 45. Mais sur les 950 autres, il en signale 48 à tort. Résultat : quand il signale la complication, il a raison moins d'une fois sur deux. La valeur prédictive dépend de la fréquence de ce que l'on cherche, pas seulement de la qualité du modèle.");
      T(s, "Une complication rare : 5 % des dossiers. Un bon modèle : sensibilité 90 %, spécificité 95 %.", { x: 0.7, y: 1.7, w: 11.9, h: 0.6, fontSize: 19 });
      const st = [["1 000", "dossiers", C.accent4], ["50", "ont la complication", C.accent3], ["45", "signalées à raison", C.accent2], ["48", "signalées à tort, parmi les 950 autres", C.accent6]];
      st.forEach(([v, l, color], i) => {
        const x = 0.7 + i * 3.03;
        box(s, x, 2.55, 2.8, 1.9);
        T(s, v, { x: x + 0.25, y: 2.65, w: 2.3, h: 0.95, fontSize: 44, bold: true, color, valign: "middle" });
        T(s, l, { x: x + 0.25, y: 3.6, w: 2.3, h: 0.75, fontSize: 14 });
        if (i < 3) arrow(s, x + 2.82, 3.5, 0.19, 0);
      });
      box(s, 0.7, 4.75, 11.9, 1.75, C.text1);
      T(s, "48 %", { x: 1.0, y: 4.75, w: 2.6, h: 1.75, fontSize: 60, bold: true, valign: "middle", color: C.background1 });
      T(s, "Valeur prédictive positive : 45 ÷ (45 + 48)", { x: 3.8, y: 4.95, w: 8.5, h: 0.5, fontSize: 18, bold: true, color: C.background1 });
      T(s, "Quand le modèle signale cette complication, il a raison moins d'une fois sur deux. Ce n'est pas le modèle qui est mauvais : c'est la complication qui est rare.", { x: 3.8, y: 5.45, w: 8.5, h: 0.95, fontSize: 15, color: C.background2 });
    }
    {
      const s = content("Lire le classement", "Un exemple fictif, pour apprendre à lire le tableau que produira la salle. Les chiffres réels seront ceux de vos extractions. Trois clés de lecture. Un rappel bas : le modèle se tait. Une précision basse : il invente. Un JSON invalide : le dossier entier compte comme manqué. Et la dernière colonne : un modèle plus juste mais trois fois plus lent n'est pas toujours le bon choix.");
      const hdr = (t) => ({ text: t, options: { bold: true, color: THEME.colors.lt1, fill: { color: THEME.colors.dk1 }, fontSize: 14 } });
      const cell = (t, o = {}) => ({ text: t, options: { fontSize: 15, color: THEME.colors.dk1, ...o } });
      const lo = { color: THEME.colors.accent6, bold: true };
      s.addTable([
        [hdr("Run"), hdr("JSON valides"), hdr("Précision"), hdr("Rappel"), hdr("F1"), hdr("Temps par dossier")],
        [cell("modèle A", { bold: true }), cell("10 / 10"), cell("0,93"), cell("0,90"), cell("0,91"), cell("40 s", lo)],
        [cell("modèle B", { bold: true }), cell("10 / 10"), cell("0,95"), cell("0,71", lo), cell("0,81"), cell("22 s")],
        [cell("modèle C", { bold: true }), cell("10 / 10"), cell("0,74", lo), cell("0,88"), cell("0,80"), cell("25 s")],
        [cell("modèle D", { bold: true }), cell("7 / 10", lo), cell("0,90"), cell("0,62", lo), cell("0,73"), cell("12 s")],
      ], { x: 0.7, y: 1.75, w: 11.9, colW: [2.4, 2.0, 1.8, 1.8, 1.5, 2.4], rowH: 0.55, border: { type: "solid", color: THEME.colors.lt2, pt: 1 }, valign: "middle", objectName: "classement fictif" });
      T(s, "Exemple fictif : vos chiffres seront ceux de la salle.", { x: 0.7, y: 4.6, w: 11.9, h: 0.4, fontSize: 14, italic: true, color: C.accent4 });
      const keys = [["B : rappel bas", "Le modèle se tait : il préfère « non précisé »."], ["C : précision basse", "Le modèle invente ou se trompe."], ["D : JSON invalides", "Un dossier refusé compte comme entièrement manqué."]];
      keys.forEach(([h, b], i) => {
        const x = 0.7 + i * 4.05;
        box(s, x, 5.1, 3.8, 1.45);
        T(s, h, { x: x + 0.25, y: 5.2, w: 3.3, h: 0.45, fontSize: 16, bold: true });
        T(s, b, { x: x + 0.25, y: 5.65, w: 3.3, h: 0.8, fontSize: 14 });
      });
    }
    {
      const s = content("Manquer ou inventer : lequel est le plus grave ?", "Question ouverte, à poser à la salle après le classement. Il n'y a pas de réponse unique : elle dépend de ce que l'on fait de la donnée. Pour repérer des patients à inclure, on veut un bon rappel. Pour remplir une base qui servira à une publication, une invention est une faute. C'est une décision clinique, pas informatique.");
      box(s, 0.7, 1.8, 5.8, 3.6);
      await dot(s, 1.0, 2.05, 0.8, C.accent3, "FaEyeSlash");
      T(s, "Manquer", { x: 2.05, y: 2.05, w: 4.2, h: 0.8, fontSize: 24, bold: true, valign: "middle" });
      T(s, "Rappel bas. Une complication présente dans le compte rendu n'entre pas dans la base.", { x: 1.0, y: 3.15, w: 5.2, h: 1.1, fontSize: 17 });
      T(s, "Grave quand on cherche des patients à inclure.", { x: 1.0, y: 4.4, w: 5.2, h: 0.8, fontSize: 15, italic: true, color: C.text2 });
      box(s, 6.8, 1.8, 5.8, 3.6);
      await dot(s, 7.1, 2.05, 0.8, C.accent6, "FaMagic");
      T(s, "Inventer", { x: 8.15, y: 2.05, w: 4.2, h: 0.8, fontSize: 24, bold: true, valign: "middle" });
      T(s, "Précision basse. Une valeur qui n'est pas dans le compte rendu entre dans la base.", { x: 7.1, y: 3.15, w: 5.2, h: 1.1, fontSize: 17 });
      T(s, "Grave quand la base nourrit une analyse ou une publication.", { x: 7.1, y: 4.4, w: 5.2, h: 0.8, fontSize: 15, italic: true, color: C.text2 });
      T(s, "C'est une décision clinique, pas informatique.", { x: 0.7, y: 5.75, w: 11.9, h: 0.7, fontSize: 22, bold: true, color: C.accent1 });
    }
  };

  const git = async () => {
    {
      const s = content("Un commit : une photo datée et signée", "Un commit enregistre l'état de tout le projet à un instant, avec son auteur, sa date et un message. Les commits se suivent : c'est l'historique. Chacun a un identifiant court. On peut toujours revenir à n'importe lequel, et comparer deux d'entre eux.");
      line(s, 1.6, 2.9, 9.0, 0);
      const cs = [["a1b2c3d", "projet de départ", "le formateur"], ["4e5f6a7", "poste: atlas, 16 Go sans GPU", "equipe-2"], ["8b9c0d1", "inférence: modèle 4B au lieu du 2B", "equipe-2"]];
      cs.forEach(([h, m, a], i) => {
        const x = 1.9 + i * 4.2;
        node(s, x, 2.9, i === 0 ? C.accent4 : C.accent5, 0.7);
        T(s, h, { x: x - 1.5, y: 2.05, w: 3.0, h: 0.4, align: "center", fontFace: MONO, fontSize: 15, bold: true, color: C.accent5 });
        T(s, m, { x: x - 1.8, y: 3.4, w: 3.6, h: 0.75, align: "center", fontSize: 16, bold: true });
        T(s, a, { x: x - 1.8, y: 4.15, w: 3.6, h: 0.4, align: "center", fontSize: 14, color: C.accent4 });
      });
      const k = [["Qui", "l'auteur"], ["Quand", "la date"], ["Pourquoi", "le message"], ["Quoi", "l'état de tous les fichiers"]];
      k.forEach(([h, b], i) => {
        const x = 0.7 + i * 3.03;
        box(s, x, 5.1, 2.8, 1.35);
        T(s, h, { x: x + 0.25, y: 5.2, w: 2.3, h: 0.5, fontSize: 19, bold: true, color: C.accent5 });
        T(s, b, { x: x + 0.25, y: 5.7, w: 2.3, h: 0.6, fontSize: 15 });
      });
    }
    {
      const s = content("Une branche : votre histoire, en parallèle", "Une branche part d'un commit et avance de son côté. Chaque poste a la sienne. Les commits d'une branche ne touchent pas les autres : l'équipe 2 peut choisir son modèle pendant que l'équipe 3 règle sa passerelle, sans se gêner. main, elle, ne bouge pas.");
      const yM = 2.5, yA = 3.9, yB = 5.3;
      line(s, 3.2, yM, 8.6, 0, C.accent4);
      [3.4, 5.6, 7.8, 10.0, 11.6].forEach((x) => node(s, x, yM, C.accent4));
      line(s, 5.6, yM, 1.4, yA - yM, C.accent5);
      line(s, 7.0, yA, 4.2, 0, C.accent5);
      [7.2, 9.2, 11.0].forEach((x) => node(s, x, yA, C.accent5));
      line(s, 7.8, yM, 1.4, yB - yM, C.accent1);
      line(s, 9.2, yB, 2.0, 0, C.accent1);
      [9.4, 11.0].forEach((x) => node(s, x, yB, C.accent1));
      pill(s, 0.7, yM - 0.22, 2.2, "main", C.accent4);
      pill(s, 0.7, yA - 0.22, 4.2, "poste/equipe-2-atlas", C.accent5);
      pill(s, 0.7, yB - 0.22, 4.2, "poste/equipe-3-orion", C.accent1);
      T(s, "Chaque rond est un commit. Les branches avancent sans se gêner ; main ne bouge pas.", { x: 0.7, y: 6.05, w: 11.9, h: 0.5, fontSize: 17, italic: true, color: C.text2 });
    }
    {
      const s = content("Du fichier modifié à la forge", "Le trajet d'une modification, en quatre lieux. Vous modifiez un fichier. git add choisit ce qui partira. git commit l'enregistre dans votre historique, sur votre machine. git push l'envoie à la forge. Tant que vous n'avez pas poussé, personne d'autre ne voit rien. git status dit à tout moment où en est chaque fichier.");
      const st = [["Votre dossier", "vous modifiez un fichier", C.accent4], ["La sélection", "ce qui partira dans le commit", C.accent3], ["Votre historique", "enregistré, sur votre machine", C.accent5], ["La forge", "visible par toute la salle", C.accent1]];
      const cmds = ["git add", "git commit", "git push"];
      st.forEach(([h, b, color], i) => {
        const x = 0.7 + i * 3.28;
        box(s, x, 2.2, 2.05, 2.6, color);
        T(s, h, { x: x + 0.1, y: 2.45, w: 1.85, h: 0.9, fontSize: 18, bold: true, align: "center", valign: "middle", color: C.background1 });
        T(s, b, { x: x + 0.1, y: 3.4, w: 1.85, h: 1.2, fontSize: 14, align: "center", color: C.background1 });
        if (i < 3) {
          arrow(s, x + 2.12, 3.5, 1.09, 0);
          T(s, cmds[i], { x: x + 2.07, y: 2.9, w: 1.19, h: 0.5, fontFace: MONO, fontSize: 12, bold: true, align: "center", valign: "middle", color: C.text1 });
        }
      });
      box(s, 0.7, 5.3, 11.9, 1.15);
      T(s, [{ text: "git status", options: { fontFace: MONO, bold: true } }, { text: "  dit à tout moment où en est chaque fichier. Tant que vous n'avez pas poussé, personne d'autre ne voit rien." }], { x: 1.0, y: 5.3, w: 11.0, h: 1.15, fontSize: 17, valign: "middle" });
    }
    {
      const s = content("Un projet, deux dépôts distants", "La leçon du basculement. Votre clone connaît deux dépôts distants. origin, c'est GitHub : d'où vous avez cloné, en lecture. salle, c'est la forge du Pi : ajoutée par ./bin/farci poste salle, en écriture. C'est le même projet aux deux endroits. git remote -v les affiche. Un projet git n'appartient à aucun site : on peut le publier où l'on veut.");
      box(s, 0.7, 1.9, 3.5, 1.5, C.text1);
      T(s, "GitHub", { x: 0.9, y: 2.0, w: 3.1, h: 0.55, fontSize: 21, bold: true, align: "center", color: C.background1 });
      T(s, "sur Internet · en lecture", { x: 0.9, y: 2.6, w: 3.1, h: 0.5, fontSize: 14, align: "center", color: C.background2 });
      box(s, 9.1, 1.9, 3.5, 1.5, C.accent5);
      T(s, "La forge du Pi", { x: 9.3, y: 2.0, w: 3.1, h: 0.55, fontSize: 21, bold: true, align: "center", color: C.background1 });
      T(s, "dans la salle · en écriture", { x: 9.3, y: 2.6, w: 3.1, h: 0.5, fontSize: 14, align: "center", color: C.background1 });
      box(s, 4.9, 1.9, 3.5, 1.5, C.accent1);
      T(s, "Votre clone", { x: 5.1, y: 2.0, w: 3.1, h: 0.55, fontSize: 21, bold: true, align: "center", color: C.background1 });
      T(s, "sur votre machine", { x: 5.1, y: 2.6, w: 3.1, h: 0.5, fontSize: 14, align: "center", color: C.background1 });
      arrow(s, 4.25, 2.65, 0.6, 0);
      arrow(s, 8.45, 2.65, 0.6, 0);
      pill(s, 3.55, 3.6, 2.0, "origin", C.accent4);
      pill(s, 7.75, 3.6, 2.0, "salle", C.accent5);
      T(s, "git clone, en ligne", { x: 2.4, y: 4.1, w: 4.3, h: 0.4, fontSize: 14, align: "center", color: C.text2 });
      T(s, "git push, en local", { x: 6.6, y: 4.1, w: 4.3, h: 0.4, fontSize: 14, align: "center", color: C.text2 });
      code(s, 0.7, 4.75, 11.9, 1.75, [
        ["$ git remote -v", VERT],
        ["origin  https://github.com/jdanion/FARCI"],
        ["salle   http://<forge>/FARCI/farci.git"],
      ], 15);
    }
    {
      const s = content("Un diff : ce qui change, ligne à ligne", "git diff montre exactement ce qui va partir : en rouge les lignes retirées, en vert les lignes ajoutées. Ici l'étudiant corrige la fiche de son poste : sa machine n'est pas une grosse configuration, et il choisit le modèle 4B. C'est aussi ce que verra l'équipe qui relira sa Pull Request.");
      code(s, 0.7, 1.8, 7.4, 4.7, [
        ["postes/equipe-2-atlas.env", GRIS], [""],
        ["  POSTE_RAM_GO=16"],
        ["- FARCI_MACHINE=grosse", ROUGE, true],
        ["+ FARCI_MACHINE=legere", VERT, true],
        ["  FARCI_EQUIPE=2"],
        ["- LLAMACPP_GGUF=", ROUGE, true],
        ["+ LLAMACPP_GGUF=Qwen3.5-4B-Q4_K_M.gguf", VERT, true],
      ], 15);
      const a = [["FaMinus", C.accent6, "En rouge", "les lignes retirées"], ["FaPlus", C.accent2, "En vert", "les lignes ajoutées"], ["FaUserMd", C.accent5, "Pour le relecteur", "c'est exactement ce qu'il verra dans votre Pull Request"]];
      for (let i = 0; i < 3; i++) {
        await dot(s, 8.5, 1.95 + i * 1.5, 0.7, a[i][1], a[i][0]);
        T(s, a[i][2], { x: 9.45, y: 1.9 + i * 1.5, w: 3.2, h: 0.45, fontSize: 19, bold: true });
        T(s, a[i][3], { x: 9.45, y: 2.38 + i * 1.5, w: 3.2, h: 0.85, fontSize: 15 });
      }
    }
    {
      const s = content("La Pull Request : faire relire avant d'intégrer", "Le circuit complet. Vous poussez votre branche. Vous ouvrez une Pull Request vers la branche commune, seance. Une autre équipe la relit : personne ne valide son propre travail. Une fois approuvée, elle est fusionnée. Tout le monde récupère alors le travail commun avec git fetch puis git merge.");
      const st = [["FaUpload", "Pousser", "votre branche arrive sur la forge"], ["FaCodeBranch", "Demander", "Pull Request vers « seance »"], ["FaUserMd", "Relire", "une autre équipe lit votre diff"], ["FaCheck", "Fusionner", "votre travail entre dans « seance »"], ["FaDownload", "Recevoir", "git fetch salle, git merge : chacun le récupère"]];
      for (let i = 0; i < 5; i++) {
        const x = 0.7 + i * 2.42;
        box(s, x, 2.0, 2.15, 3.5);
        await dot(s, x + 0.65, 2.25, 0.85, i === 2 ? C.accent3 : C.accent5, st[i][0]);
        T(s, st[i][1], { x: x + 0.1, y: 3.3, w: 1.95, h: 0.5, fontSize: 19, bold: true, align: "center" });
        T(s, st[i][2], { x: x + 0.15, y: 3.9, w: 1.85, h: 1.4, fontSize: 14, align: "center" });
        if (i < 4) arrow(s, x + 2.17, 3.75, 0.23, 0);
      }
      T(s, "Personne ne valide son propre travail.", { x: 0.7, y: 5.85, w: 11.9, h: 0.6, fontSize: 21, bold: true, color: C.accent5 });
    }
    {
      const s = content("Une séance de git, en vrai", "Toutes les commandes de la séance, dans l'ordre, telles qu'on les tape. Les six premières se font en ligne. Les deux dernières se font en local, après le basculement : poste salle ajoute le dépôt distant salle, et l'on pousse vers lui. Ne pas les faire apprendre : ./bin/farci poste donne la suivante à chaque étape.");
      code(s, 0.7, 1.75, 11.9, 4.35, [
        ["# en ligne", GRIS],
        ["$ git clone https://github.com/jdanion/FARCI farci"],
        ["$ cd farci"],
        ["$ git switch -c poste/equipe-2-atlas", VERT],
        ["$ ./bin/farci poste nouveau"],
        ["$ git add postes/equipe-2-atlas.env"],
        ['$ git commit -m "poste: atlas, 16 Go sans GPU, modèle 4B"', VERT],
        ["# en local, sur FARCI-SALLE", GRIS],
        ["$ ./bin/farci poste salle"],
        ["$ git push -u salle poste/equipe-2-atlas", VERT],
      ], 15);
      T(s, [{ text: "Perdu ?  " }, { text: "./bin/farci poste", options: { fontFace: MONO, bold: true } }, { text: "  vous donne la commande suivante." }], { x: 0.7, y: 6.3, w: 11.9, h: 0.45, fontSize: 17, color: C.text2 });
    }
    {
      const s = content("Quand ça coince", "Les quatre messages que la salle rencontrera. Aucun n'est grave. Rien n'est perdu tant que c'est commité. La seule règle : ne jamais forcer. En cas de doute, lever la main.");
      const k = [["FaKey", "Authentication failed", "Vous poussez vers origin (GitHub). Lancez ./bin/farci poste salle, puis poussez vers salle."], ["FaLock", "protected branch", "Vous poussez sur main ou seance. Poussez votre branche, puis Pull Request."], ["FaSync", "rejected : fetch first", "La forge a des commits que vous n'avez pas : git fetch salle, puis git merge."], ["FaRandom", "CONFLICT", "Deux modifications de la même ligne : ouvrir le fichier, choisir, git add, git commit."]];
      for (let i = 0; i < 4; i++) await card(s, 0.7 + (i % 2) * 6.05, 1.8 + Math.floor(i / 2) * 2.2, 5.85, 1.95, { ic: k[i][0], color: C.accent6, head: k[i][1], body: k[i][2], bodySize: 15 });
      T(s, "Rien n'est perdu tant que c'est commité. Ne forcez jamais : levez la main.", { x: 0.7, y: 6.2, w: 11.9, h: 0.5, fontSize: 17, italic: true, color: C.text2 });
    }
  };

  return { modeles, mesurer, git };
};
