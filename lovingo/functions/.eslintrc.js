module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2020, // ✅ MISE À JOUR POUR SUPPORTER L'OPTIONAL CHAINING
    sourceType: "module",
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],

    // ✅ RÈGLES CORRIGÉES POUR FIREBASE FUNCTIONS
    "max-len": ["error", {"code": 120}], // Augmenter limite à 120 caractères
    "require-jsdoc": "off", // Désactiver JSDoc obligatoire
    "no-unused-vars": "warn", // Warning au lieu d'erreur
    "object-curly-spacing": "off", // Désactiver espacement accolades
    "comma-dangle": ["error", "always-multiline"], // Virgule finale seulement multilignes
    "indent": ["error", 2, {"SwitchCase": 1}], // Indentation 2 espaces
    "no-console": "off", // Permettre console.log dans Functions
    "camelcase": "off", // Désactiver camelCase strict
    "new-cap": "off", // Désactiver capitalisation constructeurs
    "no-invalid-this": "off", // Permettre 'this' dans Functions
    "arrow-parens": ["error", "always"], // Parenthèses obligatoires pour arrow functions
    "brace-style": ["error", "1tbs", {"allowSingleLine": true}], // Style accolades
    "no-trailing-spaces": "error", // Pas d'espaces en fin de ligne
    "semi": ["error", "always"], // Point-virgule obligatoire
    "space-before-function-paren": ["error", { // Espaces avant parenthèses
      "anonymous": "always",
      "named": "never",
      "asyncArrow": "always",
    }],
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {
        "no-unused-expressions": "off", // Permettre chai expect
      },
    },
  ],
  globals: {},
};
