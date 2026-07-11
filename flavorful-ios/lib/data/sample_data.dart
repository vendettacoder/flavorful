import '../models/recipe.dart';

/// Sample recipes for the mock repository. The four library cards come from the
/// design mock; "Best Lentil Soup" carries the full 14-ingredient / 8-step /
/// 3-note detail shown in the Recipe Detail frame.
List<Recipe> buildSampleRecipes() => [
      _paneer(),
      _lentilSoup(),
      _gnocchi(),
      _cabbage(),
    ];

Recipe _lentilSoup() => Recipe(
      id: 'r-lentil-soup',
      url: 'https://cookieandkate.com/best-lentil-soup-recipe/',
      hostname: 'cookieandkate.com',
      title: 'Best Lentil Soup',
      description:
          'Rich, comforting, surprisingly easy. Curry powder and lemon make '
          'this one to come back to all winter.',
      totalMinutes: 55,
      servings: 4,
      difficulty: 'Easy',
      isFavorited: false,
      savedAt: DateTime(2026, 6, 20, 9, 12),
      ingredients: const [
        Ingredient(
            quantityRaw: '¼ cup',
            quantityValue: 0.25,
            unit: 'cup',
            name: 'olive oil'),
        Ingredient(
            quantityRaw: '1',
            quantityValue: 1,
            name: 'onion',
            sideNote: 'finely chopped'),
        Ingredient(
            quantityRaw: '2',
            quantityValue: 2,
            name: 'carrots',
            sideNote: 'peeled & diced'),
        Ingredient(
            quantityRaw: '4 cloves',
            quantityValue: 4,
            unit: 'cloves',
            name: 'garlic',
            sideNote: 'pressed'),
        Ingredient(
            quantityRaw: '2 tsp',
            quantityValue: 2,
            unit: 'tsp',
            name: 'ground cumin'),
        Ingredient(
            quantityRaw: '1 can',
            quantityValue: 1,
            unit: 'can',
            name: 'diced tomatoes',
            sideNote: '28 oz'),
        Ingredient(
            quantityRaw: '1 cup',
            quantityValue: 1,
            unit: 'cup',
            name: 'brown lentils'),
        Ingredient(
            quantityRaw: '1 tsp',
            quantityValue: 1,
            unit: 'tsp',
            name: 'curry powder'),
        Ingredient(
            quantityRaw: '½ tsp',
            quantityValue: 0.5,
            unit: 'tsp',
            name: 'dried thyme'),
        Ingredient(
            quantityRaw: '4 cups',
            quantityValue: 4,
            unit: 'cups',
            name: 'vegetable broth'),
        Ingredient(
            quantityRaw: '1 cup',
            quantityValue: 1,
            unit: 'cup',
            name: 'water'),
        Ingredient(
            quantityRaw: '1 cup',
            quantityValue: 1,
            unit: 'cup',
            name: 'chopped kale',
            sideNote: 'stems removed'),
        Ingredient(
            quantityRaw: '2 tbsp',
            quantityValue: 2,
            unit: 'tbsp',
            name: 'lemon juice',
            sideNote: 'fresh'),
        Ingredient(
            quantityRaw: '½ tsp',
            quantityValue: 0.5,
            unit: 'tsp',
            name: 'salt',
            sideNote: 'to taste'),
      ],
      method: const [
        'Warm the olive oil in a large Dutch oven over medium heat. Add the '
            'chopped onion and a pinch of salt. Cook until translucent, ~5 minutes.',
        'Add the carrots and cook until tender, 6 to 8 minutes.',
        'Add garlic, cumin, curry powder and thyme. Pour in the tomatoes and '
            'cook until broken down.',
        'Add broth, water, lentils. Bring to a boil, then simmer for 25–30 min '
            'until tender.',
        'Transfer about 2 cups of the soup to a blender and purée until smooth, '
            'then stir it back in for a creamy body.',
        'Stir in the chopped kale and cook until wilted, about 5 minutes.',
        'Remove from heat and stir in the fresh lemon juice. Taste and adjust salt.',
        'Ladle into bowls and serve warm, with crusty bread if you like.',
      ],
      notesFromPage: const [
        NoteFromPage(
            boldLeadIn: 'Make it vegan.',
            body: 'Already vegan if your broth is vegetable-based.'),
        NoteFromPage(
            boldLeadIn: 'Storage.',
            body: 'Up to 4 days in fridge, 3 months in freezer.'),
        NoteFromPage(
            boldLeadIn: 'Lentil variations.',
            body: 'French green lentils hold shape; red lentils break down for '
                'a smoother soup.'),
      ],
    );

Recipe _paneer() => Recipe(
      id: 'r-paneer',
      url:
          'https://www.indianhealthyrecipes.com/paneer-butter-masala-restaurant-style/',
      hostname: 'indianhealthyrecipes.com',
      title: 'Paneer Butter Masala',
      description: 'Creamy tomato-cashew gravy, restaurant-style.',
      totalMinutes: 45,
      servings: 4,
      difficulty: 'Medium',
      isFavorited: true,
      savedAt: DateTime(2026, 6, 22, 18, 30),
      ingredients: const [
        Ingredient(
            quantityRaw: '250 g',
            quantityValue: 250,
            unit: 'g',
            name: 'paneer',
            sideNote: 'cubed'),
        Ingredient(
            quantityRaw: '2 tbsp', quantityValue: 2, unit: 'tbsp', name: 'butter'),
        Ingredient(
            quantityRaw: '1',
            quantityValue: 1,
            name: 'onion',
            sideNote: 'roughly chopped'),
        Ingredient(
            quantityRaw: '3',
            quantityValue: 3,
            name: 'tomatoes',
            sideNote: 'pureed'),
        Ingredient(
            quantityRaw: '12',
            quantityValue: 12,
            name: 'cashews',
            sideNote: 'soaked'),
        Ingredient(
            quantityRaw: '1 tsp',
            quantityValue: 1,
            unit: 'tsp',
            name: 'red chili powder'),
        Ingredient(
            quantityRaw: '½ cup', quantityValue: 0.5, unit: 'cup', name: 'cream'),
        Ingredient(
            quantityRaw: '1 tsp',
            quantityValue: 1,
            unit: 'tsp',
            name: 'garam masala'),
      ],
      method: const [
        'Soak the cashews in warm water, then blend with the tomatoes to a '
            'smooth purée.',
        'Melt butter, sauté the onion until golden, add ginger-garlic and cook '
            'off the raw smell.',
        'Pour in the tomato-cashew purée with chili powder; simmer until it '
            'thickens and the fat separates.',
        'Stir in cream and garam masala, add the paneer, and warm through for '
            '3–4 minutes.',
      ],
      notesFromPage: const [
        NoteFromPage(
            boldLeadIn: 'Softer paneer.',
            body: 'Soak fried paneer cubes in warm water for 10 minutes before '
                'adding.'),
      ],
    );

Recipe _gnocchi() => Recipe(
      id: 'r-gnocchi',
      url: 'https://smittenkitchen.com/brown-butter-gnocchi/',
      hostname: 'smittenkitchen.com',
      title: 'Brown Butter Gnocchi',
      description: 'Nutty brown butter, crispy sage, parmesan.',
      totalMinutes: 30,
      servings: 2,
      difficulty: 'Easy',
      isFavorited: false,
      savedAt: DateTime(2026, 6, 18, 20, 5),
      ingredients: const [
        Ingredient(
            quantityRaw: '500 g',
            quantityValue: 500,
            unit: 'g',
            name: 'potato gnocchi'),
        Ingredient(
            quantityRaw: '4 tbsp', quantityValue: 4, unit: 'tbsp', name: 'butter'),
        Ingredient(
            quantityRaw: '12', quantityValue: 12, name: 'sage leaves'),
        Ingredient(
            quantityRaw: '¼ cup',
            quantityValue: 0.25,
            unit: 'cup',
            name: 'grated parmesan'),
        Ingredient(quantityRaw: '1 pinch', name: 'salt'),
      ],
      method: const [
        'Boil the gnocchi until they float, then drain well.',
        'Brown the butter in a wide skillet until it smells nutty and turns amber.',
        'Add the sage leaves and fry until crisp, then add the gnocchi and toss '
            'to coat.',
        'Finish with grated parmesan and a pinch of salt.',
      ],
      notesFromPage: const [
        NoteFromPage(
            boldLeadIn: 'Crisp edges.',
            body: 'Let the gnocchi sit undisturbed for a minute so they sear.'),
      ],
    );

Recipe _cabbage() => Recipe(
      id: 'r-cabbage',
      url: 'https://www.bonappetit.com/recipe/charred-cabbage-wedges/',
      hostname: 'bonappetit.com',
      title: 'Charred Cabbage Wedges',
      description: 'Smoky wedges with anchovy-caper butter.',
      totalMinutes: 35,
      servings: 4,
      difficulty: 'Easy',
      isFavorited: false,
      savedAt: DateTime(2026, 6, 15, 19, 40),
      ingredients: const [
        Ingredient(
            quantityRaw: '1 head',
            quantityValue: 1,
            unit: 'head',
            name: 'green cabbage',
            sideNote: 'cut into wedges'),
        Ingredient(
            quantityRaw: '3 tbsp',
            quantityValue: 3,
            unit: 'tbsp',
            name: 'olive oil'),
        Ingredient(
            quantityRaw: '4 tbsp', quantityValue: 4, unit: 'tbsp', name: 'butter'),
        Ingredient(
            quantityRaw: '4',
            quantityValue: 4,
            name: 'anchovy fillets',
            sideNote: 'minced'),
        Ingredient(
            quantityRaw: '1 tbsp',
            quantityValue: 1,
            unit: 'tbsp',
            name: 'capers',
            sideNote: 'drained'),
      ],
      method: const [
        'Heat a cast-iron pan until smoking, brush the wedges with oil, and char '
            'on each cut side.',
        'Melt the butter with the minced anchovy and capers until fragrant.',
        'Spoon the warm anchovy-caper butter over the charred wedges and serve.',
      ],
      notesFromPage: const [
        NoteFromPage(
            boldLeadIn: 'Go big.',
            body: 'Thick wedges hold together better when charring.'),
      ],
    );
