# Implementation Patterns Skill

Expert skill for platform-specific implementation patterns, best practices, and code organization.

## Backend Patterns (TypeScript + Hono + Bun)

### Project Structure
```
backend-project/
├── src/
│   ├── index.ts                 # App entry, middleware setup
│   ├── routes/                  # API routes
│   │   ├── auth.ts
│   │   ├── users.ts
│   │   └── products.ts
│   ├── services/                # Business logic, third-party integrations
│   │   ├── external-api.service.ts
│   │   ├── auth.service.ts
│   │   └── payment.service.ts
│   ├── middleware/              # Request/response middleware
│   │   ├── auth.ts
│   │   ├── error-handler.ts
│   │   └── logger.ts
│   ├── utils/                   # Shared utilities
│   ├── types/                   # TypeScript types
│   └── db/                      # Database (if used)
```

### API Endpoint Pattern
```typescript
import { Hono } from 'hono'
import { z } from 'zod'
import { authMiddleware } from '../middleware/auth'

const app = new Hono()

// Request validation schema
const createOrderSchema = z.object({
  productId: z.string().uuid(),
  quantity: z.number().int().positive(),
  shippingAddress: z.string().optional()
})

// Route with validation, auth, error handling
app.post(
  '/orders',
  authMiddleware, // Check JWT token
  async (c) => {
    try {
      // Validate input
      const body = createOrderSchema.parse(await c.req.json())

      // Business logic
      const order = await orderService.create(body)

      // Success response
      return c.json({ data: order }, 201)

    } catch (error) {
      if (error instanceof z.ZodError) {
        return c.json({ error: 'Invalid input', details: error.errors }, 400)
      }
      // Error middleware will handle unexpected errors
      throw error
    }
  }
)
```

### Service Pattern
```typescript
// services/order.service.ts
import { externalApiService } from './external-api.service'
import { paymentService } from './payment.service'

export class OrderService {
  async create(data: CreateOrderDto) {
    // 1. Validate product availability
    const item = await externalApiService.getItem(data.itemId)
    if (!item.available) {
      throw new Error('Item not available')
    }

    // 2. Create payment intent
    const paymentIntent = await paymentService.createPaymentIntent({
      amount: this.calculatePrice(data.quantity, item.price),
      currency: 'usd'
    })

    // 3. Create order
    const order = await externalApiService.createOrder({
      productId: data.itemId,
      quantity: data.quantity,
      totalAmount: this.calculatePrice(data.quantity, item.price)
    })

    return {
      id: order.id,
      product: product,
      quantity: data.quantity,
      paymentIntent: paymentIntent.client_secret
    }
  }

  private calculatePrice(quantity: number, unitPrice: number): number {
    return quantity * unitPrice
  }
}

export const orderService = new OrderService()
```

### Error Handling Pattern
```typescript
// middleware/error-handler.ts
import { Context } from 'hono'

export class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number,
    public code?: string
  ) {
    super(message)
  }
}

export const errorHandler = (err: Error, c: Context) => {
  console.error('Error:', err)

  if (err instanceof AppError) {
    return c.json({
      error: err.message,
      code: err.code
    }, err.statusCode)
  }

  // Third-party service errors
  if (err.message.includes('Payment')) {
    return c.json({
      error: 'Payment processing failed',
      code: 'PAYMENT_ERROR'
    }, 503)
  }

  // Default error
  return c.json({
    error: 'Internal server error',
    code: 'INTERNAL_ERROR'
  }, 500)
}
```

### OpenAPI Documentation Pattern
```typescript
import { swaggerUI } from '@hono/swagger-ui'
import { openAPISpecs } from 'hono-openapi'

// Generate OpenAPI spec
app.doc('/openapi.json', {
  openapi: '3.1.0',
  info: {
    title: 'YourApp API',
    version: '1.0.0'
  }
})

// Swagger UI
app.get('/docs', swaggerUI({ url: '/openapi.json' }))

// After changes, regenerate types
// bun run generate-types
```

---

## Android Patterns (Kotlin + Jetpack Compose)

### Project Structure
```
android-project/app/src/main/java/com/your-org/
├── di/                          # Hilt modules
│   ├── AppModule.kt
│   ├── NetworkModule.kt
│   └── RepositoryModule.kt
├── data/
│   ├── repository/              # Data layer
│   │   ├── AuthRepository.kt
│   │   └── ProductRepository.kt
│   ├── remote/                  # API clients
│   │   ├── ApiService.kt
│   │   └── dto/
│   └── local/                   # Local storage (Room, DataStore)
│       └── dao/
├── ui/
│   ├── screen/                  # Screen-level composables
│   │   ├── login/
│   │   │   ├── LoginScreen.kt
│   │   │   └── LoginViewModel.kt
│   │   └── products/
│   │       ├── ProductsScreen.kt
│   │       └── ProductsViewModel.kt
│   ├── component/               # Reusable components
│   └── navigation/              # Navigation setup
└── util/                        # Utilities
```

### Screen Pattern (Compose)
```kotlin
// LoginScreen.kt
@Composable
fun LoginScreen(
    viewModel: LoginViewModel = hiltViewModel(),
    onNavigateToHome: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LoginContent(
        state = state,
        onEmailChange = viewModel::updateEmail,
        onPasswordChange = viewModel::updatePassword,
        onLoginClick = viewModel::login
    )

    // Handle side effects
    LaunchedEffect(state.isAuthenticated) {
        if (state.isAuthenticated) {
            onNavigateToHome()
        }
    }
}

@Composable
private fun LoginContent(
    state: LoginState,
    onEmailChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onLoginClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Center
    ) {
        OutlinedTextField(
            value = state.email,
            onValueChange = onEmailChange,
            label = { Text("Email") },
            modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
        )

        Spacer(modifier = Modifier.height(8.dp))

        OutlinedTextField(
            value = state.password,
            onValueChange = onPasswordChange,
            label = { Text("Password") },
            modifier = Modifier.fillMaxWidth(),
            visualTransformation = PasswordVisualTransformation()
        )

        if (state.error != null) {
            Text(
                text = state.error,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(vertical = 8.dp)
            )
        }

        Button(
            onClick = onLoginClick,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp),
            enabled = !state.isLoading
        ) {
            if (state.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = MaterialTheme.colorScheme.onPrimary
                )
            } else {
                Text("Login")
            }
        }
    }
}
```

### ViewModel Pattern (NO Use Cases - Direct Repository)
```kotlin
// LoginViewModel.kt
@HiltViewModel
class LoginViewModel @Inject constructor(
    private val authRepository: AuthRepository // Direct repository access
) : ViewModel() {

    private val _state = MutableStateFlow(LoginState())
    val state: StateFlow<LoginState> = _state.asStateFlow()

    fun updateEmail(email: String) {
        _state.update { it.copy(email = email) }
    }

    fun updatePassword(password: String) {
        _state.update { it.copy(password = password) }
    }

    fun login() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }

            authRepository.login(
                email = _state.value.email,
                password = _state.value.password
            ).fold(
                onSuccess = { user ->
                    _state.update {
                        it.copy(
                            isLoading = false,
                            isAuthenticated = true
                        )
                    }
                },
                onFailure = { error ->
                    _state.update {
                        it.copy(
                            isLoading = false,
                            error = error.message ?: "Login failed"
                        )
                    }
                }
            )
        }
    }
}

data class LoginState(
    val email: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val isAuthenticated: Boolean = false,
    val error: String? = null
)
```

### Repository Pattern
```kotlin
// AuthRepository.kt
interface AuthRepository {
    suspend fun login(email: String, password: String): Result<User>
    suspend fun logout(): Result<Unit>
    fun isAuthenticated(): Flow<Boolean>
}

@Singleton
class AuthRepositoryImpl @Inject constructor(
    private val apiService: ApiService,
    private val tokenManager: TokenManager
) : AuthRepository {

    override suspend fun login(email: String, password: String): Result<User> {
        return try {
            val response = apiService.login(LoginRequest(email, password))
            tokenManager.saveTokens(response.accessToken, response.refreshToken)
            Result.success(response.user.toDomain())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun logout(): Result<Unit> {
        return try {
            tokenManager.clearTokens()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override fun isAuthenticated(): Flow<Boolean> {
        return tokenManager.accessToken.map { it != null }
    }
}
```

### Navigation Pattern (Compose)
```kotlin
// Navigation.kt
@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController()
) {
    NavHost(
        navController = navController,
        startDestination = "login"
    ) {
        composable("login") {
            LoginScreen(
                onNavigateToHome = {
                    navController.navigate("home") {
                        popUpTo("login") { inclusive = true }
                    }
                }
            )
        }

        composable("home") {
            HomeScreen(
                onNavigateToProducts = {
                    navController.navigate("products")
                }
            )
        }

        composable("products") {
            ProductsScreen(
                onNavigateBack = { navController.popBackStack() },
                onProductClick = { productId ->
                    navController.navigate("product/$productId")
                }
            )
        }

        composable(
            route = "product/{productId}",
            arguments = listOf(navArgument("productId") { type = NavType.StringType })
        ) { backStackEntry ->
            val productId = backStackEntry.arguments?.getString("productId")
            ProductDetailScreen(
                productId = productId,
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
```

---

## iOS Patterns (Swift + SwiftUI)

### Project Structure
```
ios-project/Sources/
├── App/
│   └── YourAppApp.swift         # App entry point
├── Models/                      # Data models
│   ├── User.swift
│   └── Product.swift
├── ViewModels/                  # Observable view models
│   ├── LoginViewModel.swift
│   └── ProductsViewModel.swift
├── Views/                       # SwiftUI views
│   ├── Login/
│   │   ├── LoginView.swift
│   │   └── LoginComponents.swift
│   └── Products/
│       ├── ProductsView.swift
│       └── ProductRow.swift
├── Services/                    # Business logic, API clients
│   ├── APIService.swift
│   ├── AuthService.swift
│   └── ProductService.swift
└── Utilities/                   # Helpers, extensions
```

### View Pattern
```swift
// LoginView.swift
struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)

                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: {
                    Task { await viewModel.login() }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Login")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
            .padding()
            .navigationTitle("Login")
            .navigationDestination(isPresented: $viewModel.isAuthenticated) {
                HomeView()
            }
        }
    }
}
```

### ViewModel Pattern
```swift
// LoginViewModel.swift
@MainActor
class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var error: String?

    private let authService: AuthService

    init(authService: AuthService = .shared) {
        self.authService = authService
    }

    func login() async {
        isLoading = true
        error = nil

        do {
            let user = try await authService.login(
                email: email,
                password: password
            )
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
```

### Service Pattern
```swift
// AuthService.swift
actor AuthService {
    static let shared = AuthService()

    private let apiClient: APIClient
    private var accessToken: String?

    private init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func login(email: String, password: String) async throws -> User {
        let request = LoginRequest(email: email, password: password)
        let response: LoginResponse = try await apiClient.post("/auth/login", body: request)

        accessToken = response.accessToken
        KeychainManager.shared.save(response.accessToken, forKey: "accessToken")
        KeychainManager.shared.save(response.refreshToken, forKey: "refreshToken")

        return response.user
    }

    func logout() {
        accessToken = nil
        KeychainManager.shared.delete(forKey: "accessToken")
        KeychainManager.shared.delete(forKey: "refreshToken")
    }

    func isAuthenticated() -> Bool {
        return KeychainManager.shared.get(forKey: "accessToken") != nil
    }
}
```

### Navigation Pattern (Modern)
```swift
// AppCoordinator.swift
@MainActor
class AppCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var isAuthenticated = false

    func navigateToHome() {
        isAuthenticated = true
        path = NavigationPath() // Reset navigation stack
    }

    func navigateToProducts() {
        path.append(Route.products)
    }

    func navigateToProduct(_ productId: String) {
        path.append(Route.productDetail(id: productId))
    }

    func popToRoot() {
        path = NavigationPath()
    }
}

enum Route: Hashable {
    case products
    case productDetail(id: String)
    case order(productId: String)
}

// App.swift
@main
struct YourAppApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            if coordinator.isAuthenticated {
                NavigationStack(path: $coordinator.path) {
                    HomeView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .products:
                                ProductsView()
                            case .productDetail(let id):
                                ProductDetailView(productId: id)
                            case .order(let productId):
                                OrderView(productId: productId)
                            }
                        }
                }
                .environmentObject(coordinator)
            } else {
                LoginView()
                    .environmentObject(coordinator)
            }
        }
    }
}
```

---

## Common Patterns Across Platforms

### Error Handling
- **Backend**: Custom AppError with status codes
- **Android**: Result<T> with sealed classes for states
- **iOS**: Error protocol with LocalizedError

### State Management
- **Backend**: Stateless (Redis for temp data)
- **Android**: StateFlow/SharedFlow with immutable state
- **iOS**: @Published properties with @MainActor

### Dependency Injection
- **Backend**: Constructor injection (services as singletons)
- **Android**: Hilt with @Inject
- **iOS**: Protocol-oriented with default implementations

### Async Operations
- **Backend**: Async/await (Bun native)
- **Android**: Coroutines with viewModelScope
- **iOS**: async/await with Task

## Implementation Checklist

When implementing a feature, follow this order:

### Backend
1. Define request/response DTOs with Zod schemas
2. Create service methods (business logic)
3. Add route handlers with middleware
4. Update OpenAPI documentation
5. Write tests (unit + integration)
6. Run `bun run generate-types`

### Android
1. Define data models (DTOs + Domain)
2. Create Repository interface + implementation
3. Inject Repository into ViewModel
4. Create ViewModel with StateFlow
5. Build Composable UI with state
6. Add navigation handling
7. Write tests (ViewModel + UI)

### iOS
1. Define data models (Codable)
2. Create Service methods (async functions)
3. Create ViewModel (@MainActor class)
4. Build SwiftUI View with @StateObject
5. Add navigation handling
6. Write tests (ViewModel + integration)

## Usage

This skill provides implementation guidance during:
- /prd:dev:start - Reference patterns while coding
- Code reviews - Validate against established patterns
- Architecture decisions - Choose appropriate patterns
