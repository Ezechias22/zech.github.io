// Script d'initialisation des données Firebase
// À exécuter dans la console Firebase

// Collection des cadeaux par défaut
db.collection('gifts').doc('rose').set({
  id: 'rose',
  name: 'Rose',
  icon: '🌹',
  animationPath: 'assets/animations/rose.json',
  price: 10,
  rarity: 'common',
  isPremiumOnly: false
});

db.collection('gifts').doc('heart').set({
  id: 'heart',
  name: 'Cœur',
  icon: '❤️',
  animationPath: 'assets/animations/heart.json',
  price: 5,
  rarity: 'common',
  isPremiumOnly: false
});

db.collection('gifts').doc('diamond').set({
  id: 'diamond',
  name: 'Diamant',
  icon: '💎',
  animationPath: 'assets/animations/diamond.json',
  price: 100,
  rarity: 'epic',
  isPremiumOnly: true
});

db.collection('gifts').doc('crown').set({
  id: 'crown',
  name: 'Couronne',
  icon: '👑',
  animationPath: 'assets/animations/crown.json',
  price: 500,
  rarity: 'legendary',
  isPremiumOnly: true
});

console.log('Collections initiales créées!');
