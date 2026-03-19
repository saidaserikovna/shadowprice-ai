# ShadowPrice AI — Flutter App

## Детектор скрытых переплат

### Установка

1. Убедитесь, что у вас установлен Flutter SDK (>=3.2.0)
2. Создайте новый Flutter проект: `flutter create shadowprice_ai`
3. Замените содержимое папки `lib/` файлами из этого архива
4. Замените `pubspec.yaml`
5. Выполните `flutter pub get`

### Настройка Firebase

1. Создайте проект в [Firebase Console](https://console.firebase.google.com)
2. Добавьте Android и iOS приложения
3. Скачайте `google-services.json` (Android) и `GoogleService-Info.plist` (iOS)
4. Разместите файлы согласно документации Firebase
5. Включите **Authentication** → Email/Password и Google Sign-In
6. Создайте базу данных **Firestore** в production mode

### Firestore Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /profiles/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /tracked_products/{docId} {
      allow read, write: if request.auth != null && resource == null || request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
    match /price_history/{docId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
  }
}
```

### Запуск

```bash
flutter run
```

### Функционал

- ✅ Google Sign-In (Firebase Auth)
- ✅ Email/Password аутентификация
- ✅ Автоматическая отправка email при регистрации
- ✅ Сохранение сессии (persistSession)
- ✅ Firebase Firestore (профили, товары, история цен)
- ✅ Полный CRUD (создание, чтение, обновление, удаление)
- ✅ AI анализ цены (симуляция)
- ✅ График истории цен (fl_chart)
- ✅ Сравнение платформ (Amazon, AliExpress, eBay, Kaspi)
- ✅ Региональный анализ цен
- ✅ AI рекомендации (Покупать/Подождать)
- ✅ Уведомления о снижении цены (toggle)
- ✅ Дашборд с статистикой
- ✅ AI Инсайты
- ✅ Настройки профиля
- ✅ Тёмная тема "Data-First Noir"
- ✅ Адаптивный дизайн
- ✅ Кастомный логотип "Sentinel S"

### Структура

```
lib/
├── main.dart              # Entry point + AuthGate
├── core/
│   └── theme.dart         # ShadowPrice тема
├── models/
│   └── product_model.dart # Product + PriceHistory модели
├── services/
│   ├── auth_service.dart  # Firebase Auth (Google + Email)
│   └── price_service.dart # Firestore CRUD + AI анализ
├── screens/
│   ├── auth_screen.dart   # Логин / Регистрация
│   ├── home_screen.dart   # Bottom Nav контейнер
│   ├── dashboard_screen.dart # Дашборд с товарами
│   ├── analyze_screen.dart   # AI анализ цены
│   ├── insights_screen.dart  # AI инсайты
│   └── settings_screen.dart  # Профиль и настройки
└── widgets/
    └── price_chart.dart   # Переиспользуемый график
```
