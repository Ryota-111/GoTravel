//
//  LoginView.swift
//  GoTravel
//
//  Created by Ryota Fujitsuka on 2025/09/22.
//

import SwiftUI

struct LoginView: View {
    // ViewModelを管理する
    @StateObject private var viewModel = TodoViewModel()
    @State private var newTitle: String = ""

    var body: some View {
        NavigationView {
            VStack {
                // 新しいTodoを入力する欄
                HStack {
                    TextField("新しいタスク", text: $newTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("追加") {
                        viewModel.addTodo(title: newTitle)
                        newTitle = ""
                    }
                }
                .padding()

                // Todoリストを表示
                List {
                    ForEach(viewModel.todos) { todo in
                        HStack {
                            Button(action: {
                                viewModel.toggleDone(todo: todo)
                            }) {
                                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(todo.isDone ? .green : .gray)
                            }
                            Text(todo.title)
                                .strikethrough(todo.isDone)
                        }
                    }
                }
            }
            .navigationTitle("Todoリスト")
        }
    }
}
