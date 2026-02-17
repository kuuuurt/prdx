# Implementation Patterns Skill

Expert skill for platform-specific implementation patterns, best practices, and code organization. Agents should **discover the actual framework from the codebase** and adapt these principles accordingly.

## Backend Patterns

**Discover the stack from:** `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`

### Project Structure Principles
```
backend-project/
├── src/
│   ├── routes/           # API route handlers
│   ├── services/         # Business logic, third-party integrations
│   ├── middleware/       # Request/response middleware
│   ├── utils/            # Shared utilities
│   ├── types/            # Type definitions
│   └── db/               # Database (if used)
```

### API Endpoint Pattern (Framework-Agnostic)
```
Route with validation, auth, error handling:
1. Apply authentication middleware
2. Validate request body against schema
3. Execute business logic via service
4. Return structured response

Error handling:
- Validation errors → 400
- Auth errors → 401/403
- Not found → 404
- Server errors → 500
```

### Service Pattern
```
Service responsibilities:
1. Coordinate business logic
2. Call external services
3. Handle transactions
4. Return domain objects (not HTTP responses)

Keep services framework-agnostic - they shouldn't know about HTTP.
```

### Error Handling Pattern
```
Error structure:
- Consistent response format across all endpoints
- Include error code for client-side handling
- Include user-friendly message
- Log detailed errors server-side only
```

### Implementation Checklist

1. Define request/response schemas with validation
2. Create service methods (business logic)
3. Add route handlers with middleware
4. Document API according to project conventions
5. Write tests (unit + integration)

---

## Android Patterns (Kotlin + Jetpack Compose)

**Discover the stack from:** `build.gradle` / `build.gradle.kts`
- DI: Hilt, Koin, Dagger, or manual injection
- Persistence: Room, SQLDelight, DataStore, Realm
- Networking: Retrofit, Ktor, OkHttp

### Project Structure Principles
```
android-project/app/src/main/java/com/your-org/
├── di/                          # DI modules (if using DI framework)
├── data/
│   ├── repository/              # Data layer
│   └── remote/                  # API clients
├── ui/
│   ├── screen/                  # Screen-level composables
│   │   └── feature/
│   │       ├── FeatureScreen.kt
│   │       └── FeatureViewModel.kt
│   ├── component/               # Reusable components
│   └── navigation/              # Navigation setup
└── util/                        # Utilities
```

### Screen Pattern (Compose)
```kotlin
@Composable
fun FeatureScreen(
    viewModel: FeatureViewModel,  // Inject using project's DI
    onNavigateToNext: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    FeatureContent(
        state = state,
        onAction = viewModel::handleAction
    )

    // Handle side effects
    LaunchedEffect(state.shouldNavigate) {
        if (state.shouldNavigate) {
            onNavigateToNext()
        }
    }
}

@Composable
private fun FeatureContent(
    state: FeatureState,
    onAction: (FeatureAction) -> Unit
) {
    // Pure UI, no side effects
}
```

### ViewModel Pattern
```kotlin
class FeatureViewModel(
    private val repository: FeatureRepository  // Direct repository access
) : ViewModel() {

    private val _state = MutableStateFlow(FeatureState())
    val state: StateFlow<FeatureState> = _state.asStateFlow()

    fun handleAction(action: FeatureAction) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }

            repository.doSomething()
                .onSuccess { result ->
                    _state.update { it.copy(isLoading = false, data = result) }
                }
                .onFailure { error ->
                    _state.update { it.copy(isLoading = false, error = error.message) }
                }
        }
    }
}

data class FeatureState(
    val isLoading: Boolean = false,
    val data: Data? = null,
    val error: String? = null
)
```

### Repository Pattern
```kotlin
interface FeatureRepository {
    suspend fun getData(): Result<Data>
    fun observeData(): Flow<Data>
}

class FeatureRepositoryImpl(
    private val apiService: ApiService,  // Discover from project
    private val localStore: LocalStore   // Discover from project
) : FeatureRepository {
    // Implementation adapts to project's networking/persistence
}
```

### Navigation Pattern (Compose)
```kotlin
@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController()
) {
    NavHost(
        navController = navController,
        startDestination = "home"
    ) {
        composable("home") {
            HomeScreen(
                onNavigateToFeature = {
                    navController.navigate("feature")
                }
            )
        }
        composable("feature") {
            FeatureScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
```

### Implementation Checklist

1. Define data models
2. Create Repository interface + implementation (adapt to project's patterns)
3. Create ViewModel with StateFlow
4. Build Composable UI with state
5. Add navigation handling
6. Write tests (ViewModel + UI)

---

## iOS Patterns (Swift + SwiftUI)

**Discover the stack from:** `Package.swift`, `Podfile`, `Cartfile`
- Networking: Alamofire, URLSession wrappers, custom clients
- Persistence: Core Data, SwiftData, Realm
- Image loading: Kingfisher, SDWebImage, Nuke, AsyncImage

### Project Structure Principles
```
ios-project/Sources/
├── App/
│   └── YourAppApp.swift         # App entry point
├── Models/                      # Data models
├── ViewModels/                  # Observable view models
├── Views/                       # SwiftUI views
│   └── Feature/
│       ├── FeatureView.swift
│       └── FeatureComponents.swift
├── Services/                    # Business logic, API clients
└── Utilities/                   # Helpers, extensions
```

### View Pattern
```swift
struct FeatureView: View {
    @StateObject private var viewModel = FeatureViewModel()
    // Or use @Observable for iOS 17+

    var body: some View {
        NavigationStack {
            FeatureContent(
                state: viewModel.state,
                onAction: viewModel.handleAction
            )
            .navigationTitle("Feature")
        }
    }
}

// Pure content view for previews
struct FeatureContent: View {
    let state: FeatureState
    let onAction: (FeatureAction) -> Void

    var body: some View {
        // UI implementation
    }
}
```

### ViewModel Pattern
```swift
@MainActor
class FeatureViewModel: ObservableObject {
    @Published var state = FeatureState()

    private let service: FeatureService

    init(service: FeatureService = .shared) {
        self.service = service
    }

    func handleAction(_ action: FeatureAction) {
        Task {
            state.isLoading = true

            do {
                let result = try await service.fetchData()
                state.data = result
            } catch {
                state.error = error.localizedDescription
            }

            state.isLoading = false
        }
    }
}

struct FeatureState {
    var isLoading = false
    var data: Data?
    var error: String?
}
```

### Service Pattern
```swift
actor FeatureService {
    static let shared = FeatureService()

    private let apiClient: APIClient  // Discover from project

    private init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchData() async throws -> Data {
        // Implementation adapts to project's networking
    }
}
```

### Navigation Pattern (Modern)
```swift
@MainActor
class AppCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func navigateToFeature(_ id: String) {
        path.append(Route.feature(id: id))
    }

    func popToRoot() {
        path = NavigationPath()
    }
}

enum Route: Hashable {
    case feature(id: String)
    case detail(id: String)
}

// App.swift
@main
struct YourAppApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $coordinator.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .feature(let id):
                            FeatureView(id: id)
                        case .detail(let id):
                            DetailView(id: id)
                        }
                    }
            }
            .environmentObject(coordinator)
        }
    }
}
```

### Implementation Checklist

1. Define data models (Codable)
2. Create Service methods (async functions)
3. Create ViewModel (@MainActor class)
4. Build SwiftUI View with @StateObject
5. Add navigation handling
6. Write tests (ViewModel + integration)

---

## Frontend Patterns (Web)

**Discover the stack from:** `package.json`, `vite.config.*`, `next.config.*`, `nuxt.config.*`, `svelte.config.*`, `angular.json`
- Framework: React, Vue, Svelte, Angular, Next.js, Nuxt, SvelteKit
- State: Redux, Zustand, Pinia, Context API, signals
- Styling: Tailwind CSS, CSS Modules, styled-components, Emotion
- Data fetching: React Query, SWR, tRPC, server components

### Project Structure Principles
```
frontend-project/src/
├── app/                        # App entry, routing, layouts
├── components/                 # Shared UI components
│   ├── ui/                     # Primitives (Button, Input, Card)
│   └── feature/                # Feature-specific components
├── pages/ or routes/           # Route-level components
├── hooks/ or composables/      # Shared logic (framework-specific)
├── services/ or api/           # API client, data fetching
├── stores/ or state/           # State management
├── types/                      # TypeScript types/interfaces
└── utils/                      # Pure utility functions
```

### Component Pattern
```
Component responsibilities:
1. Render UI based on props/state
2. Handle user interactions
3. Delegate business logic to hooks/services

Keep components focused:
- Container components: data fetching, state management
- Presentational components: pure UI, receive data via props
- Compose small components into larger features
```

### Data Fetching Pattern
```
Data fetching responsibilities:
1. Abstract API calls into a service/client layer
2. Use framework's data fetching primitives (React Query, SWR, server components, etc.)
3. Handle loading, error, and success states
4. Cache and invalidate data appropriately

Never fetch directly in UI components - always go through a service layer.
```

### Form Pattern
```
Form handling:
1. Define validation schema (Zod, Yup, or native)
2. Use form library if available (React Hook Form, Formik, VeeValidate)
3. Show validation errors inline
4. Handle submission with loading/error states
5. Disable submit during processing
```

### Implementation Checklist

1. Define TypeScript types/interfaces for data
2. Create API service methods (data fetching layer)
3. Build reusable components (if needed)
4. Create page/route component with state management
5. Add form handling and validation (if applicable)
6. Ensure responsive design and accessibility
7. Write tests (component + integration)

---

## Common Patterns Across Platforms

### Error Handling
- **Backend**: Consistent error response format with codes
- **Android**: Result<T> with sealed classes for states
- **iOS**: Error protocol with LocalizedError

### State Management
- **Backend**: Stateless (use cache for temporary data)
- **Android**: StateFlow/SharedFlow with immutable state
- **iOS**: @Published properties with @MainActor

### Dependency Injection
- **Backend**: Constructor injection (discover framework)
- **Android**: Discover from build.gradle (Hilt, Koin, manual)
- **iOS**: Protocol-oriented with default implementations

### Async Operations
- **Backend**: async/await (language-native)
- **Android**: Coroutines with viewModelScope
- **iOS**: async/await with Task

## Usage

This skill provides implementation guidance during:
- /prdx:implement - Reference patterns while coding
- Code reviews - Validate against established patterns
- Architecture decisions - Choose appropriate patterns

**Key principle**: Discover the actual frameworks and libraries from the project's dependency files, then adapt these patterns accordingly.
