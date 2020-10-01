//
//  ContentView.swift
//  TCA-Navigation-PoC
//
//  Created by Maciej Kozlowski on 24/09/2020.
//

import SwiftUI
import ComposableArchitecture

struct NavigationState<State> {
    var state: State
    var isActive: Bool

    mutating func activate(state nextState: State) {
        isActive = true
        state = nextState
    }
}

struct NextState: Equatable {
    var nextState: Next2State?
}

enum NextAction: Equatable {
    case present(Bool)
    case next(Next2Action)
}

typealias NextReducer = Reducer<NextState, NextAction, Void>

let nextReducer = NextReducer.combine(
    NextReducer { state, action, _ in
        switch action {
        case let .present(present):
            state.nextState = present ? Next2State() : nil
            return .none

        case .next:
            return .none
        }
    }
)

struct NextView: View {

    let store: Store<NextState, NextAction>

    var body: some View {
        NavigationItemView { back in
            WithViewStore(store) { viewStore in
                ZStack {
                    Color.red.ignoresSafeArea()
                    VStack {
                        Button(action: back, label: {
                            Text("Back")
                        })
                        NavigationLink(
                            destination: IfLetStore(
                                self.store.scope(
                                    state: { $0.nextState },
                                    action: NextAction.next
                                ),
                                then: { Next2View(store: $0) }
                            ),
                            isActive: viewStore.binding(
                                get: { $0.nextState != nil },
                                send: NextAction.present
                            ),
                            label: { Text("Navigate2") }
                        )
                    }
                }
            }
        }
    }
}

// MARK: -
struct Next2State: Equatable {}

enum Next2Action: Equatable {}

let next2Reducer = Reducer<Next2State, Next2Action, Void> { state, action, _ in
    return .none
}

struct Next2View: View {

    let store: Store<Next2State, Next2Action>

    var body: some View {
        NavigationItemView { back in
            WithViewStore(store) { viewStore in
                ZStack {
                    Color.orange.ignoresSafeArea()
                    VStack {
                        Button(action: back, label: {
                            Text("Back")
                        })
                        Button(action: {}, label: {
                            Text("BackToRoot")
                        })
                    }
                }
            }
        }
    }
}

// MARK: -

struct ContentState: Equatable {
    var nextState: NextState?
}

enum ContentAction: Equatable {
    case present(Bool)
    case next(NextAction)
}

typealias ContentReducer = Reducer<ContentState, ContentAction, Void>

let contentReducer = ContentReducer.combine(
    nextReducer.optional().pullback(
        state: \.nextState,
        action: /ContentAction.next,
        environment: { _ in () }
    ),
    ContentReducer { state, action, _ in
        switch action {
        case let .present(present):
            state.nextState = present ? NextState() : nil
            return .none

        case .next:
            return .none
        }
    }
)
.debug()

struct ContentView: View {

    let store: Store<ContentState, ContentAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            NavigationView {
                NavigationLink(
                    destination: IfLetStore(
                        self.store.scope(
                            state: { $0.nextState },
                            action: ContentAction.next
                        ),
                        then: { NextView(store: $0) }
                    ),
                    isActive: viewStore.binding(
                        get: { $0.nextState != nil },
                        send: ContentAction.present
                    ),
                    label: { Text("Navigate") }
                )
            }
        }
    }
}

struct NavigatinStoreLink<State, Action, Content>: View where Content: View {

    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    // private let store: Store<State?, Action>

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        NavigationLink(
            destination: Text("Destination"),
            isActive: .constant(true),
            label: {
                Text("Navigate")
            }
        )
    }
}

// MARK: -

struct NavigationItemView<Content>: View where Content: View {

    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>

    let content: (@escaping () -> Void) -> Content

    var body: some View {
        content { presentationMode.wrappedValue.dismiss() }
    }
}

// MARK: -

import SwiftUI

struct ContentViewRoot: View {
    @State var isActive : Bool = false

    var body: some View {
        NavigationView {
            NavigationLink(
                destination: ContentView2(rootIsActive: self.$isActive),
                isActive: self.$isActive
            ) {
                Text("Hello, World!")
            }
            .isDetailLink(false)
            .navigationBarTitle("Root")
        }
    }
}

struct ContentView2: View {
    @Binding var rootIsActive : Bool

    var body: some View {
        NavigationLink(
            destination: ContentView3(shouldPopToRootView: self.$rootIsActive)
        ) {
            Text("Hello, World #2!")
        }
        .isDetailLink(false)
        .navigationBarTitle("Two")
    }
}

struct ContentView3: View {
    @Binding var shouldPopToRootView : Bool

    var body: some View {
        VStack {
            Text("Hello, World #3!")
            Button(action: { self.shouldPopToRootView = false } ){
                Text("Pop to root")
            }
        }.navigationBarTitle("Three")
    }
}


typealias NavigationStackState = [NavigationStackItemState]

protocol NavigationStackItemState {
  var navigationID: UUID { get }
  var navigationTitle: String { get }
}

enum NavigationStackAction {
  // navigation actions:
  case set([NavigationStackItemState])
  case push(NavigationStackItemState)
  case pop
  case popToRoot
}

struct NavigationStackEnvironment {}

typealias NavigationStackReducer = Reducer<NavigationStackState, NavigationStackAction, NavigationStackEnvironment>

let navigationStackReducer = NavigationStackReducer.combine(
  // navigation stack reducer:
  NavigationStackReducer { state, action, _ in
    switch action {
    // generic navigation actions:
    case .set(let items):
      state = items
      return .none

    case .push(let item):
      state.append(item)
      return .none

    case .pop:
      _ = state.popLast()
      return .none

    case .popToRoot:
      state = Array(state.prefix(1))
      return .none
    }
  }
)

typealias NavigationStackStore = Store<NavigationStackState, NavigationStackAction>
typealias NavigationStackViewStore = ViewStore<NavigationStackState, NavigationStackAction>
typealias NavigationStackItemViewFactory = (NavigationStackStore, NavigationStackItemState) -> AnyView
typealias NavigationStackItemOptionalViewFactory = (NavigationStackStore, NavigationStackItemState) -> AnyView?

func combine(
  _ factories: NavigationStackItemOptionalViewFactory...
) -> NavigationStackItemViewFactory {
  return { store, item in
    for factory in factories {
      if let view = factory(store, item) {
        return view
      }
    }
    fatalError("Unknown navigation item state: <\(type(of: item))>")
  }
}

func == (lhs: NavigationStackState, rhs: NavigationStackState) -> Bool {
  lhs.map(\.navigationID) == rhs.map(\.navigationID)
}

struct RootNavigationView: View {

  let store: NavigationStackStore
  let viewFactory: NavigationStackItemViewFactory

  init(store: NavigationStackStore, viewFactory: @escaping NavigationStackItemViewFactory) {
    self.store = store
    self.viewFactory = viewFactory
  }

  var body: some View {
    NavigationView {
      WithViewStore(store, removeDuplicates: ==) { viewStore -> AnyView? in
        var state = viewStore.state

        guard !state.isEmpty else {
          return nil
        }

        return self.view(
          item: state.removeFirst(),
          state: state
        )
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }

  func view(item: NavigationStackItemState, state: NavigationStackState) -> AnyView {
    guard !state.isEmpty else {
      return viewFactory(store, item)
    }

    var state = state
    let nextItem = state.removeFirst()
    let nextState: (NavigationStackState) -> Bool = {
      $0.contains { $0.navigationID == nextItem.navigationID }
    }

    return AnyView(
      ZStack {
        viewFactory(store, item)
        WithViewStore(store.scope(state: nextState)) { viewStore in
          NavigationLink(
            destination: self.view(item: nextItem, state: state),
            isActive: .init(
              get: { viewStore.state },
              set: { _ in
                if viewStore.state {
                  viewStore.send(.pop)
                }
              }
            ),
            label: EmptyView.init
          )
          .isDetailLink(false)
        }
      }
    )
  }
}
