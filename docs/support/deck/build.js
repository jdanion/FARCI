// FARCI — générateur du diaporama docs/support/FARCI-support-de-cours.pptx
//
//   npm install pptxgenjs react react-dom react-icons sharp
//   node docs/support/deck/build.js docs/support/FARCI-support-de-cours.pptx
//
// Le diaporama se modifie aussi directement dans PowerPoint ; ce script sert à
// le régénérer en entier. Piège connu : PowerPoint REFUSE un fichier dont une
// forme a une hauteur ou une largeur négative (voir la fonction arrow).
const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const fa = require("react-icons/fa");
// applyTheme écrit les couleurs du thème dans le fichier (pptxgenjs ne sait pas
// le faire) : c'est le script apply_theme.js de l'outillage PowerPoint utilisé
// pour générer ce diaporama. Sans lui, le diaporama sort aux couleurs par défaut.
const applyTheme = process.env.FARCI_PPTX_APPLY_THEME
  ? require(process.env.FARCI_PPTX_APPLY_THEME).applyTheme
  : async () => console.warn("FARCI_PPTX_APPLY_THEME absent : couleurs du thème non appliquées");

const OUT = process.argv[2];
const THEME = {
  name: "FARCI",
  headFontFace: "Cambria",
  bodyFontFace: "Calibri",
  colors: {
    dk1: "0B1020", lt1: "FFFFFF", dk2: "1B2445", lt2: "EEF2FF",
    accent1: "4F46E5", accent2: "15803D", accent3: "B45309", accent4: "64748B",
    accent5: "0F766E", accent6: "BE123C", hlink: "4F46E5", folHlink: "64748B",
  },
};
const MONO = "Courier New";

async function icon(name, color = "FFFFFF") {
  const svg = ReactDOMServer.renderToStaticMarkup(React.createElement(fa[name], { color: "#" + color, size: 256 }));
  const buf = await sharp(Buffer.from(svg)).resize(256, 256, { fit: "contain", background: { r: 0, g: 0, b: 0, alpha: 0 } }).png().toBuffer();
  return "image/png;base64," + buf.toString("base64");
}

(async () => {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE"; // 13.33 x 7.5
  pres.title = "FARCI — support de cours";
  pres.author = "FARCI";
  pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
  const C = pres.SchemeColor;

  pres.defineSlideMaster({
    title: "Titre", background: { color: C.text1 },
    objects: [
      { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 1.6, w: 11.7, h: 1.6, fontSize: 80, bold: true, color: C.background1, align: "left", valign: "bottom", margin: 0 }, text: "" } },
      { placeholder: { options: { name: "body", type: "body", x: 0.8, y: 3.35, w: 10.5, h: 1.3, fontSize: 26, color: C.background2, align: "left", valign: "top", margin: 0 }, text: "" } },
    ],
  });
  pres.defineSlideMaster({
    title: "Section", background: { color: C.text2 },
    objects: [
      { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 2.5, w: 11.7, h: 1.3, fontSize: 54, bold: true, color: C.background1, align: "left", valign: "bottom", margin: 0 }, text: "" } },
      { placeholder: { options: { name: "body", type: "body", x: 0.8, y: 4.0, w: 10.5, h: 1.2, fontSize: 22, color: C.background2, align: "left", valign: "top", margin: 0 }, text: "" } },
    ],
  });
  pres.defineSlideMaster({
    title: "Contenu", background: { color: C.background1 },
    objects: [
      { placeholder: { options: { name: "title", type: "title", x: 0.7, y: 0.45, w: 11.9, h: 0.95, fontSize: 36, bold: true, color: C.text1, align: "left", valign: "middle", margin: 0 }, text: "" } },
      { text: { text: "FARCI — support de cours", options: { x: 0.7, y: 6.95, w: 6, h: 0.3, fontSize: 10, color: C.accent4, margin: 0 } } },
    ],
    slideNumber: { x: 12.0, y: 6.95, w: 0.65, h: 0.3, fontSize: 10, color: C.accent4, align: "right" },
  });

  let section = "";
  const sec = (title) => { section = title; pres.addSection({ title }); };
  const add = (masterName) => pres.addSlide({ masterName, sectionTitle: section });
  const content = (title, notes) => { const s = add("Contenu"); s.addText(title, { placeholder: "title" }); s.addNotes(notes); return s; };
  const divider = (title, sub, notes) => { const s = add("Section"); s.addText(title, { placeholder: "title" }); s.addText(sub, { placeholder: "body" }); s.addNotes(notes); return s; };

  let n = 0;
  const T = (s, text, o) => s.addText(text, { isTextBox: true, margin: 0, valign: "top", color: C.text1, fontSize: 15, objectName: "texte " + (++n), ...o });
  const box = (s, x, y, w, h, color = C.background2, o = {}) =>
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.12, fill: { color }, line: { color, width: 0 }, objectName: "carte " + (++n), ...o });
  const dot = async (s, x, y, d, color, name) => {
    s.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color }, line: { color, width: 0 }, objectName: "pastille " + (++n) });
    if (name) s.addImage({ data: await icon(name), x: x + d * 0.25, y: y + d * 0.25, w: d * 0.5, h: d * 0.5, objectName: "icone " + (++n) });
  };
  const num = (s, x, y, d, color, label) => {
    s.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color }, line: { color, width: 0 }, objectName: "pastille " + (++n) });
    s.addText(String(label), { isTextBox: true, x, y, w: d, h: d, margin: 0, align: "center", valign: "middle", bold: true, fontSize: 18, color: C.background1, objectName: "numero " + (++n) });
  };
  // Carte : pastille icône, titre, texte.
  const card = async (s, x, y, w, h, { ic, color = C.accent1, head, body, bodySize = 14 }) => {
    box(s, x, y, w, h);
    await dot(s, x + 0.25, y + 0.25, 0.6, color, ic);
    T(s, head, { x: x + 1.0, y: y + 0.25, w: w - 1.2, h: 0.6, fontSize: 18, bold: true, valign: "middle" });
    T(s, body, { x: x + 0.25, y: y + 1.0, w: w - 0.5, h: h - 1.15, fontSize: bodySize });
  };
  // PowerPoint refuse une hauteur négative : une flèche montante est une
  // flèche descendante retournée (flipV), posée plus haut.
  const arrow = (s, x, y, w, h = 0, color = C.accent4) =>
    s.addShape(pres.shapes.LINE, { x, y: h < 0 ? y + h : y, w, h: Math.abs(h), flipV: h < 0,
      line: { color, width: 2, endArrowType: "triangle" }, objectName: "fleche " + (++n) });
  const bullets = (items, size = 15) => items.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < items.length - 1, paraSpaceAfter: 6, fontSize: size } }));

  // ───────────────────────────── Ouverture
  sec("Ouverture");
  {
    const s = add("Titre");
    s.addText("FARCI", { placeholder: "title" });
    s.addText("Construire, utiliser et casser une plateforme d'IA pour la recherche clinique", { placeholder: "body" });
    const steps = ["1  Construire", "2  Utiliser", "3  Casser"];
    steps.forEach((t, i) => {
      box(s, 0.8 + i * 2.75, 5.3, 2.5, 0.7, C.accent1);
      T(s, t, { x: 0.8 + i * 2.75, y: 5.3, w: 2.5, h: 0.7, align: "center", valign: "middle", bold: true, fontSize: 18, color: C.background1 });
    });
    T(s, "Atelier de 4 heures · support de cours", { x: 0.8, y: 6.5, w: 8, h: 0.4, fontSize: 14, color: C.background2 });
    s.addNotes("Accueil. Dire en une phrase ce qu'on va faire : construire une plateforme d'IA sur les machines de la salle, s'en servir sur des dossiers médicaux synthétiques, puis la casser pour voir ce qui tient. Annoncer que le pré-test arrive dans deux minutes.");
  }
  {
    const s = content("Une IA en médecine est un système", "Message central. Une application d'IA n'est pas « appeler une API ». Montrer les six pièces : chacune sera montée par une équipe. Insister : ce sont des pièces remplaçables, et c'est tout l'intérêt.");
    T(s, "Ce n'est pas « appeler une API ».", { x: 0.7, y: 1.9, w: 4.6, h: 1.4, fontSize: 30, bold: true, color: C.accent1 });
    T(s, "C'est faire tenir ensemble six pièces, et pouvoir en changer une sans casser les autres.", { x: 0.7, y: 3.5, w: 4.4, h: 1.6, fontSize: 18 });
    const tiles = [
      ["FaBrain", "Un modèle", "les connaissances"], ["FaCogs", "Un runtime", "le logiciel qui l'exécute"],
      ["FaExchangeAlt", "Une passerelle", "le point d'entrée unique"], ["FaFileMedical", "Des documents", "à protéger avant tout"],
      ["FaBalanceScale", "Une mesure", "comparée à une référence"], ["FaSearch", "Des traces", "pour comprendre"],
    ];
    for (let i = 0; i < tiles.length; i++) {
      const x = 5.7 + (i % 2) * 3.55, y = 1.8 + Math.floor(i / 2) * 1.6;
      box(s, x, y, 3.3, 1.35);
      await dot(s, x + 0.25, y + 0.35, 0.65, C.accent1, tiles[i][0]);
      T(s, tiles[i][1], { x: x + 1.1, y: y + 0.25, w: 2.1, h: 0.45, fontSize: 18, bold: true });
      T(s, tiles[i][2], { x: x + 1.1, y: y + 0.72, w: 2.1, h: 0.45, fontSize: 14, color: C.accent4 });
    }
  }
  {
    const s = content("Trois étapes, une séance", "Décrire les trois étapes. Étape 1 : le tableau passe du secours au vert, équipe par équipe. Étape 2 : le même problème pour tous. Étape 3 : avant chaque panne, la salle parie.");
    const cols = [
      [C.accent1, "Construire", "Chaque équipe monte sa brique. Le tableau de la salle se remplit jusqu'à CLINICAL PIPELINE READY.", "0:20 → 1:50"],
      [C.accent5, "Utiliser", "Des comptes rendus médicaux deviennent des variables structurées, comparées à une référence.", "2:00 → 3:10"],
      [C.accent6, "Casser", "On arrête un runtime, on renvoie une réponse invalide. Que reste-t-il debout ?", "3:10 → 3:45"],
    ];
    cols.forEach(([color, head, body, when], i) => {
      const x = 0.7 + i * 4.05;
      box(s, x, 1.8, 3.8, 4.7);
      num(s, x + 0.3, 2.1, 0.8, color, i + 1);
      T(s, head, { x: x + 0.3, y: 3.1, w: 3.2, h: 0.6, fontSize: 28, bold: true, color });
      T(s, body, { x: x + 0.3, y: 3.85, w: 3.2, h: 1.7, fontSize: 16 });
      T(s, when, { x: x + 0.3, y: 5.8, w: 3.2, h: 0.4, fontSize: 14, color: C.accent4, fontFace: MONO });
    });
  }
  {
    const s = content("Ce que vous saurez en sortant", "Les attendus. Lire les trois colonnes. Insister sur git : c'est un objectif pour tout le monde, quelle que soit l'équipe. Le détail est dans COURS.md, section 2.");
    const cols = [
      ["FaComments", C.accent1, "Expliquer", ["pourquoi un LLM peut se tromper avec aplomb", "la différence entre un modèle et un runtime", "pourquoi on valide avant d'écrire en base", "ce que vaut un score sans référence", "ce qui ne sort jamais de la salle"]],
      ["FaCodeBranch", C.accent5, "Vous servir de git", ["cloner un projet", "créer votre branche", "enregistrer une modification", "la publier", "demander et faire une relecture"]],
      ["FaServer", C.accent3, "Faire tourner la plateforme", ["démarrer la brique de votre équipe", "lire le tableau de la salle", "lancer une extraction", "lire un score et une trace", "prédire l'effet d'une panne"]],
    ];
    for (let i = 0; i < cols.length; i++) {
      const [ic, color, head, items] = cols[i]; const x = 0.7 + i * 4.05;
      box(s, x, 1.8, 3.8, 4.8);
      await dot(s, x + 0.3, 2.05, 0.65, color, ic);
      T(s, head, { x: x + 1.15, y: 2.05, w: 2.5, h: 0.65, fontSize: 19, bold: true, valign: "middle" });
      T(s, bullets(items), { x: x + 0.3, y: 3.0, w: 3.25, h: 3.4 });
    }
  }
  {
    const s = content("Ce qui n'est pas attendu", "Rassurer. Personne ne doit savoir programmer. Les commandes ne sont pas à retenir : chacune affiche la suivante. Le critère de réussite est oral et individuel.");
    const items = ["Savoir programmer", "Connaître Docker, le réseau ou Linux", "Retenir des commandes : chacune vous donne la suivante", "Terminer le bonus de votre équipe"];
    for (let i = 0; i < items.length; i++) {
      await dot(s, 0.7, 1.95 + i * 1.05, 0.6, C.accent4, "FaTimes");
      T(s, items[i], { x: 1.55, y: 1.95 + i * 1.05, w: 4.9, h: 0.6, fontSize: 18, valign: "middle" });
    }
    box(s, 7.0, 1.8, 5.6, 4.4, C.text1);
    T(s, "Le critère de réussite", { x: 7.4, y: 2.2, w: 4.8, h: 0.5, fontSize: 16, color: C.background2 });
    T(s, "En fin de séance, chacun explique une notion avec ses mots.", { x: 7.4, y: 2.85, w: 4.8, h: 2.2, fontSize: 30, bold: true, color: C.background1 });
    T(s, "Comme à un collègue non informaticien.", { x: 7.4, y: 5.25, w: 4.8, h: 0.5, fontSize: 16, italic: true, color: C.background2 });
  }
  {
    const s = content("Pré-test : six minutes, anonyme", "Lancer le pré-test Wooclap. Afficher le code de l'événement. Dire que ce n'est pas noté, que les mêmes questions reviennent à la fin, et qu'on comparera les deux devant la salle. Ne pas afficher les bonnes réponses maintenant.");
    await dot(s, 0.7, 2.0, 1.3, C.accent1, "FaMobileAlt");
    T(s, "wooclap.com", { x: 2.4, y: 1.95, w: 6, h: 0.8, fontSize: 40, bold: true, color: C.accent1 });
    T(s, "Le code de l'événement est affiché par le formateur.", { x: 2.4, y: 2.8, w: 6.5, h: 0.5, fontSize: 18 });
    const cards = [["Pas noté", "Répondez ce que vous pensez, sans chercher."], ["Les mêmes questions à la fin", "La différence, c'est ce que la séance vous aura appris."], ["« Je ne sais pas » est une réponse", "Elle est plus utile qu'un hasard heureux."]];
    cards.forEach(([h, b], i) => {
      const x = 0.7 + i * 4.05;
      box(s, x, 4.1, 3.8, 2.3);
      T(s, h, { x: x + 0.3, y: 4.35, w: 3.2, h: 0.8, fontSize: 18, bold: true });
      T(s, b, { x: x + 0.3, y: 5.2, w: 3.2, h: 1.0, fontSize: 15 });
    });
  }

  // ───────────────────────────── Les notions
  sec("Les notions");
  divider("Les notions", "Huit idées, chacune avec son image en langage de médecine", "Transition. Les diapositives suivantes servent pendant toute la séance : y revenir au moment où la notion apparaît dans la salle.");
  {
    const s = content("Un LLM : un collaborateur junior", "Notion 1. Un LLM produit la suite de mots la plus plausible. Il ne consulte rien et ne sait pas qu'il ne sait pas. Conséquence pratique : on relit. À redire à l'étape 2, au premier JSON rejeté.");
    await dot(s, 0.7, 1.9, 1.2, C.accent1, "FaUserGraduate");
    T(s, "Très instruit, toujours bien rédigé, et parfois faux.", { x: 2.2, y: 1.9, w: 10.4, h: 1.2, fontSize: 26, bold: true, valign: "middle" });
    box(s, 0.7, 3.5, 5.8, 2.9);
    T(s, "Ce qu'il fait", { x: 1.0, y: 3.75, w: 5.2, h: 0.5, fontSize: 18, bold: true, color: C.accent2 });
    T(s, "Il écrit, mot après mot, la suite la plus plausible.", { x: 1.0, y: 4.35, w: 5.2, h: 1.8, fontSize: 20 });
    box(s, 6.8, 3.5, 5.8, 2.9);
    T(s, "Ce qu'il ne fait pas", { x: 7.1, y: 3.75, w: 5.2, h: 0.5, fontSize: 18, bold: true, color: C.accent6 });
    T(s, "Il ne consulte pas une base de connaissances, et ne sait pas qu'il ne sait pas.", { x: 7.1, y: 4.35, w: 5.2, h: 1.8, fontSize: 20 });
  }
  {
    const s = content("Le modèle n'est pas le runtime", "Notion 2. Le livre et la personne qui le lit à voix haute. Montrer le nom med-extraction : les applications ne connaissent que lui. À redire quand l'équipe 2 passe au vert.");
    const cols = [["FaBook", C.accent1, "Le modèle", "Un fichier de chiffres : les connaissances. Rien ne s'exécute tout seul.", "Qwen3.5-4B · MedGemma 4B · Ornith-1.5-9B"], ["FaVolumeUp", C.accent5, "Le runtime", "Le logiciel qui charge le modèle et répond aux questions.", "Ollama · llama.cpp"]];
    for (let i = 0; i < 2; i++) {
      const [ic, color, head, body, ex] = cols[i]; const x = 0.7 + i * 6.1;
      box(s, x, 1.8, 5.8, 3.3);
      await dot(s, x + 0.3, 2.05, 0.8, color, ic);
      T(s, head, { x: x + 1.35, y: 2.05, w: 4.2, h: 0.8, fontSize: 24, bold: true, valign: "middle" });
      T(s, body, { x: x + 0.3, y: 3.1, w: 5.2, h: 1.1, fontSize: 17 });
      T(s, ex, { x: x + 0.3, y: 4.35, w: 5.2, h: 0.45, fontSize: 14, fontFace: MONO, color: C.accent4 });
    }
    box(s, 0.7, 5.4, 11.9, 1.15, C.text1);
    T(s, [{ text: "Les applications demandent toujours ", options: { color: C.background1 } }, { text: "med-extraction", options: { fontFace: MONO, bold: true, color: C.background1 } }, { text: " : elles ignorent ce qui répond.", options: { color: C.background1 } }], { x: 1.0, y: 5.4, w: 11.3, h: 1.15, fontSize: 19, valign: "middle" });
  }
  {
    const s = content("La passerelle : un seul numéro", "Notion 3 et 4. Le standard téléphonique de l'hôpital. Une seule adresse ; derrière, on distribue, on bascule en cas de panne, on mesure. Le contrat : la même façon de poser une question à toutes les briques. À redire à la panne 01 et à la panne 06.");
    const apps = ["Programme d'extraction", "Interface de discussion"];
    apps.forEach((a, i) => { box(s, 0.7, 2.2 + i * 1.7, 3.0, 1.1); T(s, a, { x: 0.85, y: 2.2 + i * 1.7, w: 2.7, h: 1.1, fontSize: 16, align: "center", valign: "middle" }); arrow(s, 3.75, 2.75 + i * 1.7, 1.3, i === 0 ? 0.6 : -0.6); });
    box(s, 5.1, 2.45, 3.1, 2.3, C.accent1);
    T(s, "Passerelle", { x: 5.1, y: 2.75, w: 3.1, h: 0.6, fontSize: 24, bold: true, align: "center", color: C.background1 });
    T(s, "distribuer · réessayer\nbasculer · mesurer", { x: 5.1, y: 3.45, w: 3.1, h: 0.9, fontSize: 15, align: "center", color: C.background1 });
    const rts = [["Runtime principal", C.accent2], ["Runtime de secours", C.accent3]];
    rts.forEach(([r, color], i) => { arrow(s, 8.25, 3.35 + i * 0.5, 1.3, i === 0 ? -0.6 : 0.6); box(s, 9.6, 2.2 + i * 1.7, 3.0, 1.1, color); T(s, r, { x: 9.6, y: 2.2 + i * 1.7, w: 3.0, h: 1.1, fontSize: 16, bold: true, align: "center", valign: "middle", color: C.background1 }); });
    T(s, "Le contrat : toutes les briques se parlent de la même façon. On en remplace une sans réécrire le reste.", { x: 0.7, y: 5.5, w: 11.9, h: 0.9, fontSize: 18, italic: true, color: C.text2 });
  }
  {
    const s = content("La chaîne complète", "Vue d'ensemble de ce que la salle construit. Suivre un compte rendu de gauche à droite. L'observabilité est dessinée à côté, pas sur le chemin : si elle tombe, l'extraction continue (panne 07).");
    const steps = [["FaFileMedical", "Compte rendu", "4"], ["FaUserSecret", "Pseudonymisation", "4"], ["FaExchangeAlt", "Passerelle", "3"], ["FaBrain", "Modèle", "2"], ["FaCheckCircle", "Validation", "7"], ["FaBalanceScale", "Évaluation", "6"]];
    for (let i = 0; i < steps.length; i++) {
      const x = 0.7 + i * 2.02;
      box(s, x, 2.0, 1.75, 2.3);
      await dot(s, x + 0.5, 2.2, 0.75, C.accent1, steps[i][0]);
      T(s, steps[i][1], { x: x + 0.05, y: 3.1, w: 1.65, h: 0.6, fontSize: 14, bold: true, align: "center", valign: "middle" });
      T(s, "équipe " + steps[i][2], { x: x + 0.05, y: 3.75, w: 1.65, h: 0.35, fontSize: 12, align: "center", color: C.accent4 });
      if (i < steps.length - 1) arrow(s, x + 1.78, 3.15, 0.22);
    }
    box(s, 0.7, 4.9, 11.85, 1.5, C.text2);
    await dot(s, 1.0, 5.3, 0.7, C.accent5, "FaSearch");
    T(s, "Observabilité (équipe 5) : chaque requête laisse une trace. Elle est branchée à côté de la chaîne, jamais dessus.", { x: 2.0, y: 4.9, w: 10.3, h: 1.5, fontSize: 17, valign: "middle", color: C.background1 });
  }
  {
    const s = content("Une réponse n'est pas une donnée", "Notion 5. Le modèle remplit un formulaire ; la réponse est contrôlée. Ici l'âge est écrit en toutes lettres : la réponse est rejetée et rien n'entre dans la base. C'est la panne 04.");
    box(s, 0.7, 1.8, 6.2, 4.7, C.text1);
    T(s, [
      { text: "{", options: { breakLine: true } },
      { text: '  "age": "soixante ans",', options: { breakLine: true, color: "FCA5A5", bold: true } },
      { text: '  "sexe": "F",', options: { breakLine: true } },
      { text: '  "diagnostic": "adénocarcinome",', options: { breakLine: true } },
      { text: '  "stade_pT": "pT2",', options: { breakLine: true } },
      { text: '  "complication": "Non"', options: { breakLine: true } },
      { text: "}" },
    ], { x: 1.0, y: 2.1, w: 5.7, h: 4.1, fontFace: MONO, fontSize: 17, color: C.background1, paraSpaceAfter: 5 });
    await dot(s, 7.4, 1.9, 0.9, C.accent6, "FaTimes");
    T(s, "Rejetée", { x: 8.55, y: 1.9, w: 4, h: 0.9, fontSize: 32, bold: true, color: C.accent6, valign: "middle" });
    T(s, bullets(["l'âge devait être un nombre", "rien n'est écrit dans la base de recherche", "l'erreur est tracée, avec sa cause"], 18), { x: 7.4, y: 3.2, w: 5.2, h: 1.9 });
    T(s, "Un formulaire typé, contrôlé à chaque réponse : c'est ce qui sépare un texte plausible d'une donnée.", { x: 7.4, y: 5.3, w: 5.2, h: 1.1, fontSize: 15, italic: true, color: C.text2 });
  }
  {
    const s = content("Un score ne vaut que par sa référence", "Notion 6. Le gold standard : la bonne réponse, connue d'avance. Faire le calcul avec la salle : 10 signalées, 8 réelles, 16 à trouver. C'est la question C8 du test. À redire devant le classement.");
    T(s, "Le système signale 10 complications. 8 sont réelles. Il y en avait 16 à trouver.", { x: 0.7, y: 1.75, w: 11.9, h: 0.6, fontSize: 19 });
    const stats = [["80 %", "Précision", "8 justes sur 10 signalées", C.accent2], ["50 %", "Rappel", "8 trouvées sur 16 à trouver", C.accent3]];
    stats.forEach(([v, l, d, color], i) => {
      const x = 0.7 + i * 4.05;
      box(s, x, 2.6, 3.8, 3.0);
      T(s, v, { x: x + 0.3, y: 2.75, w: 3.2, h: 1.3, fontSize: 66, bold: true, color, valign: "middle" });
      T(s, l, { x: x + 0.3, y: 4.1, w: 3.2, h: 0.5, fontSize: 20, bold: true });
      T(s, d, { x: x + 0.3, y: 4.65, w: 3.2, h: 0.6, fontSize: 15, color: C.accent4 });
    });
    box(s, 8.8, 2.6, 3.8, 3.0, C.text1);
    T(s, "Gold standard", { x: 9.1, y: 2.85, w: 3.2, h: 0.6, fontSize: 22, bold: true, color: C.background1 });
    T(s, "Pour chaque dossier, la bonne réponse est connue d'avance. Tout score s'y compare.", { x: 9.1, y: 3.55, w: 3.2, h: 1.9, fontSize: 16, color: C.background2 });
    T(s, "« Un F1 de 0,84 », cité sans référence, ne veut rien dire.", { x: 0.7, y: 5.9, w: 11.9, h: 0.6, fontSize: 19, italic: true, color: C.text2 });
  }
  {
    const s = content("Casser pour comprendre", "Notions 8 et 9. Avant chaque panne, faire parier la salle : survivra, ne survivra pas. Puis casser, observer sur le tableau et dans les traces, réparer, dire la leçon en une phrase.");
    const cards = [["FaPowerOff", "Le runtime principal s'arrête", "Le secours répond : la redondance existe vraiment."], ["FaBug", "Le modèle renvoie un JSON invalide", "Rien n'est écrit : une réponse n'est pas une donnée."], ["FaUnlink", "La passerelle d'une équipe tombe", "L'adresse de la salle ne change pas."], ["FaEyeSlash", "L'outil de traces disparaît", "L'extraction continue : l'observabilité n'est pas sur le chemin."]];
    for (let i = 0; i < 4; i++) await card(s, 0.7 + (i % 2) * 6.05, 1.8 + Math.floor(i / 2) * 2.4, 5.85, 2.15, { ic: cards[i][0], color: C.accent6, head: cards[i][1], body: cards[i][2], bodySize: 16 });
  }
  {
    const s = content("Local d'abord", "Notion 10. Internet a deux usages dans la salle, pas un de plus : récupérer le code et télécharger les modèles. Les dossiers, les questions, les réponses et les traces ne sortent jamais. C'est ce qui rend l'approche acceptable pour des données de santé.");
    box(s, 0.7, 1.8, 5.8, 4.6);
    await dot(s, 1.0, 2.05, 0.75, C.accent4, "FaGlobeEurope");
    T(s, "Peut passer par Internet", { x: 2.0, y: 2.05, w: 4.3, h: 0.75, fontSize: 20, bold: true, valign: "middle" });
    T(s, bullets(["le code du projet : GitHub", "les modèles et les logiciels, au moment du téléchargement"], 18), { x: 1.0, y: 3.2, w: 5.2, h: 2.6 });
    box(s, 6.8, 1.8, 5.8, 4.6, C.text1);
    await dot(s, 7.1, 2.05, 0.75, C.accent2, "FaLock");
    T(s, "Ne sort jamais de la salle", { x: 8.1, y: 2.05, w: 4.3, h: 0.75, fontSize: 20, bold: true, valign: "middle", color: C.background1 });
    T(s, bullets(["les comptes rendus", "les questions posées au modèle", "ses réponses", "les traces"], 18), { x: 7.1, y: 3.2, w: 5.2, h: 2.6, color: C.background1 });
  }

  const more = require("./more.js")({ pres, C, THEME, MONO, content, divider, sec, T, box, dot, num, card, arrow, bullets });
  await more.modeles();
  await more.mesurer();

  // ───────────────────────────── Git
  sec("Git");
  divider("Git, en détail", "L'outil que vous emportez, quelle que soit votre équipe", "Transition. Git n'est pas la brique d'une équipe : tout le monde clone, crée sa branche, commite, pousse et fait relire.");
  {
    const s = content("Git : le dossier patient du projet", "Rien ne s'efface, tout est daté et signé. Lire les six mots avec leur analogie. Le vocabulaire complet est dans docs/GIT.md.");
    const terms = [["FaFolderOpen", "Dépôt", "le dossier patient complet, historique compris"], ["FaPen", "Commit", "une observation datée et signée"], ["FaCodeBranch", "Branche", "votre version, sans toucher celle des autres"], ["FaUpload", "Push", "transmettre vos observations"], ["FaUserMd", "Pull Request", "demander l'avis d'un confrère avant d'intégrer"], ["FaArchive", "Forge", "les archives : GitHub, ou Gitea sur place"]];
    for (let i = 0; i < 6; i++) await card(s, 0.7 + (i % 3) * 4.05, 1.8 + Math.floor(i / 3) * 2.4, 3.8, 2.15, { ic: terms[i][0], color: C.accent5, head: terms[i][1], body: terms[i][2], bodySize: 16 });
  }
  {
    const s = content("Trois lieux, un seul projet", "GitHub est la référence, joignable depuis la faculté. Gitea est le même projet, hébergé dans la salle : c'est ce qu'installe un hôpital dont le code ne doit pas sortir. Les commandes sont les mêmes. Vous clonez, puis vous poussez sur la forge de la salle.");
    const places = [["FaGithub", C.text1, "GitHub", "La référence du projet. Accessible de partout. Vous y lisez ; plus tard, vous y créez votre copie."], ["FaServer", C.accent5, "Gitea, la forge de la salle", "Le même projet, sur une machine que l'on possède. Vous y poussez votre branche."], ["FaLaptop", C.accent1, "Votre ordinateur", "Votre clone, sur votre branche : le projet adapté à votre machine."]];
    for (let i = 0; i < 3; i++) {
      const [ic, color, head, body] = places[i]; const x = 0.7 + i * 4.05;
      box(s, x, 1.8, 3.8, 3.6);
      await dot(s, x + 0.3, 2.05, 0.9, color, ic);
      T(s, head, { x: x + 0.3, y: 3.1, w: 3.2, h: 0.55, fontSize: 20, bold: true });
      T(s, body, { x: x + 0.3, y: 3.7, w: 3.2, h: 1.55, fontSize: 15 });
    }
    T(s, "Les fichiers lourds (un modèle pèse de 1 à 18 Go) ne vont jamais dans git : ils se téléchargent à part.", { x: 0.7, y: 5.7, w: 11.9, h: 0.8, fontSize: 17, italic: true, color: C.text2 });
  }
  {
    const s = content("Votre parcours, en six gestes", "Les six gestes de la séance. Ne pas faire retenir les commandes : ./bin/farci poste donne la suivante à chaque fois. Dire quand chaque geste a lieu : clone et branche à l'accueil, commit à 0:20, push et Pull Request à 1:15.");
    const steps = [["Cloner", "git clone <adresse> farci"], ["Créer sa branche", "git switch -c poste/equipe-2-atlas"], ["Adapter", "./bin/farci poste nouveau"], ["Enregistrer", 'git commit -m "poste: atlas, 16 Go"'], ["Publier", "git push -u origin <votre branche>"], ["Faire relire", "Pull Request vers « seance »"]];
    steps.forEach(([head, cmd], i) => {
      const x = 0.7 + (i % 2) * 6.05, y = 1.8 + Math.floor(i / 2) * 1.6;
      box(s, x, y, 5.85, 1.4);
      num(s, x + 0.25, y + 0.35, 0.7, C.accent5, i + 1);
      T(s, head, { x: x + 1.2, y: y + 0.18, w: 4.5, h: 0.5, fontSize: 19, bold: true, valign: "middle" });
      T(s, cmd, { x: x + 1.2, y: y + 0.75, w: 4.5, h: 0.45, fontSize: 14, fontFace: i === 5 ? undefined : MONO, color: C.text2, valign: "middle" });
    });
  }
  {
    const s = content("Une branche par poste", "Chaque machine a sa branche et sa fiche. La fiche dit ce que la machine est et ce qu'elle fait. Un portable de 16 Go prend le petit modèle, une station avec carte graphique le grand. Le surnom est celui de la machine, jamais celui d'une personne. Aucun mot de passe dans une fiche.");
    box(s, 0.7, 1.8, 5.6, 4.6, C.text1);
    T(s, "poste/equipe-2-atlas", { x: 1.0, y: 2.05, w: 5.0, h: 0.5, fontFace: MONO, fontSize: 18, bold: true, color: C.background1 });
    T(s, [
      { text: "POSTE_RAM_GO=16", options: { breakLine: true } },
      { text: "POSTE_GPU=", options: { breakLine: true } },
      { text: "FARCI_EQUIPE=2", options: { breakLine: true } },
      { text: "FARCI_MACHINE=legere", options: { breakLine: true } },
      { text: "FARCI_INFERENCE_PRIMARY=llamacpp" },
    ], { x: 1.0, y: 2.9, w: 5.0, h: 3.0, fontFace: MONO, fontSize: 15, color: C.background2, paraSpaceAfter: 8 });
    const pts = [["FaLaptop", "Votre matériel", "Mémoire, carte graphique : la fiche décrit la machine."], ["FaUsers", "Votre rôle", "Équipe, runtime, parcours : ce que la machine fait dans le projet."], ["FaCompass", "Jamais perdu", "./bin/farci poste donne la commande git suivante."]];
    for (let i = 0; i < 3; i++) {
      await dot(s, 6.8, 1.9 + i * 1.55, 0.75, C.accent5, pts[i][0]);
      T(s, pts[i][1], { x: 7.85, y: 1.85 + i * 1.55, w: 4.75, h: 0.45, fontSize: 19, bold: true });
      T(s, pts[i][2], { x: 7.85, y: 2.35 + i * 1.55, w: 4.75, h: 0.8, fontSize: 15 });
    }
  }

  await more.git();

  // ───────────────────────────── La séance
  sec("La séance");
  divider("La séance", "Quatre heures, neuf équipes, une règle", "Transition vers l'organisation pratique.");
  {
    const s = content("Quatre heures", "Le minutage. La pause n'est jamais supprimée. Le moment clé de l'étape 1 est CLINICAL PIPELINE READY, vers 1:30. La clôture n'est jamais coupée : c'est là que chacun explique une notion.");
    const rows = [["0:00", "Accueil", "pré-test, clone, votre branche", C.accent4, 20], ["0:20", "Étape 1 — Construire", "premier commit, votre brique, Pull Request", C.accent1, 90], ["1:50", "Pause", "", C.accent4, 10], ["2:00", "Étape 2 — Utiliser", "extraction des dossiers", C.accent5, 50], ["2:50", "Évaluation", "classement, une trace lue ensemble", C.accent3, 20], ["3:10", "Étape 3 — Casser", "quatre pannes, un pari avant chacune", C.accent6, 35], ["3:45", "Clôture", "une notion chacun, post-test", C.accent4, 15]];
    rows.forEach(([t, head, body, color, min], i) => {
      const y = 1.75 + i * 0.7;
      T(s, t, { x: 0.7, y, w: 0.9, h: 0.55, fontFace: MONO, fontSize: 15, valign: "middle", color: C.accent4 });
      box(s, 1.7, y, 0.9 + (min / 90) * 3.2, 0.55, color);
      T(s, head, { x: 6.1, y, w: 3.0, h: 0.55, fontSize: 16, bold: true, valign: "middle" });
      T(s, body, { x: 9.15, y, w: 3.5, h: 0.55, fontSize: 14, valign: "middle", color: C.text2 });
    });
  }
  {
    const s = content("Neuf équipes, une brique chacune", "Les équipes. Chaque équipe a une fiche d'une page et un objectif minimal atteignable en 45 minutes. Toutes démarrent en même temps. La forge est tenue par le formateur si l'équipe 0 n'existe pas.");
    const teams = [["0", "La forge", "Gitea"], ["1", "Réseau et tableau", "l'adresse de la salle"], ["2", "Inférence", "un modèle qui répond"], ["3", "Passerelle", "le point d'entrée"], ["4", "Documents", "pseudonymisation"], ["5", "Observabilité", "les traces"], ["6", "Évaluation", "les scores"], ["7", "Applications", "extraction, discussion"], ["8", "Agents", "supervision"]];
    teams.forEach(([nb, head, body], i) => {
      const x = 0.7 + (i % 3) * 4.05, y = 1.8 + Math.floor(i / 3) * 1.6;
      box(s, x, y, 3.8, 1.4);
      num(s, x + 0.25, y + 0.35, 0.7, C.accent1, nb);
      T(s, head, { x: x + 1.15, y: y + 0.2, w: 2.5, h: 0.5, fontSize: 18, bold: true, valign: "middle" });
      T(s, body, { x: x + 1.15, y: y + 0.72, w: 2.5, h: 0.45, fontSize: 14, color: C.accent4, valign: "middle" });
    });
  }
  {
    const s = content("Le tableau de la salle", "Lire le tableau projeté. Au départ tout est en REF : la machine de référence rend chaque service. Quand une équipe livre, sa ligne passe à UP. La règle des dix minutes : on lève la main, personne n'attend.");
    const st = [["UP", C.accent2, "Votre brique répond, et la salle s'en sert."], ["REF", C.accent3, "La machine de référence rend le service à votre place."], ["DOWN", C.accent6, "Personne ne rend ce service."]];
    st.forEach(([l, color, d], i) => {
      const y = 1.9 + i * 1.15;
      box(s, 0.7, y, 1.7, 0.8, color);
      T(s, l, { x: 0.7, y, w: 1.7, h: 0.8, fontSize: 22, bold: true, align: "center", valign: "middle", color: C.background1 });
      T(s, d, { x: 2.7, y, w: 4.1, h: 0.8, fontSize: 16, valign: "middle" });
    });
    box(s, 7.2, 1.8, 5.4, 4.5, C.text1);
    await dot(s, 7.55, 2.15, 0.9, C.accent3, "FaHandPaper");
    T(s, "La règle des dix minutes", { x: 7.55, y: 3.25, w: 4.7, h: 0.6, fontSize: 24, bold: true, color: C.background1 });
    T(s, "Bloqué depuis dix minutes ? Levez la main. La référence sert déjà à votre place : personne n'attend, et vous continuez à comprendre.", { x: 7.55, y: 3.95, w: 4.7, h: 2.1, fontSize: 16, color: C.background2 });
    T(s, "Au départ, tout est en REF : c'est voulu.", { x: 0.7, y: 5.6, w: 6.1, h: 0.6, fontSize: 17, italic: true, color: C.text2 });
  }
  {
    const s = content("Comment nous saurons que c'est réussi", "Les quatre mesures. Le pré-test et le post-test ont les mêmes questions : leur comparaison est montrée à la salle à la fin. Le questionnaire de satisfaction sert à améliorer la séance suivante.");
    const steps = [["À l'arrivée", "Pré-test", "ce que vous connaissez déjà"], ["Pendant", "Tableau et branche", "ce que vous avez construit"], ["À la clôture", "Une notion à l'oral", "ce que vous avez compris"], ["À la clôture", "Post-test et avis", "ce que vous avez appris, ce qu'il faut améliorer"]];
    steps.forEach(([when, head, body], i) => {
      const x = 0.7 + i * 3.03;
      box(s, x, 2.0, 2.8, 3.9);
      num(s, x + 0.3, 2.3, 0.7, C.accent1, i + 1);
      T(s, when, { x: x + 0.3, y: 3.25, w: 2.3, h: 0.4, fontSize: 13, color: C.accent4 });
      T(s, head, { x: x + 0.3, y: 3.65, w: 2.3, h: 0.85, fontSize: 19, bold: true });
      T(s, body, { x: x + 0.3, y: 4.55, w: 2.3, h: 1.2, fontSize: 15 });
      if (i < 3) arrow(s, x + 2.82, 3.95, 0.19);
    });
    T(s, "Rien n'est noté. Tout est anonyme.", { x: 0.7, y: 6.15, w: 11.9, h: 0.5, fontSize: 17, italic: true, color: C.text2 });
  }
  {
    const s = add("Section");
    s.addText("Ce que vous emportez", { placeholder: "title" });
    s.addText(bullets(["votre branche, et la façon de la pousser sur votre compte GitHub", "le projet complet, à relancer chez vous", "de quoi héberger votre propre forge", "dix idées sur ce qu'est, et n'est pas, une IA en recherche clinique"], 22), { placeholder: "body", h: 2.6 });
    s.addNotes("Clôture. Montrer une fois le fork sur GitHub et le git remote add qui permet d'y pousser sa branche. Lancer le post-test puis le questionnaire de satisfaction. Projeter la comparaison pré-test / post-test.");
  }

  await pres.writeFile({ fileName: OUT });
  await applyTheme(OUT, THEME);
  console.log("écrit :", OUT);
})();
