class ApiConfig {
  static const gameSlug = 'arrow-puzzle';
  static const playerApiBaseUrl = String.fromEnvironment(
    'NISHARC_API_BASE_URL',
    defaultValue: 'https://nisharcstudios.vercel.app/api',
  );
}
