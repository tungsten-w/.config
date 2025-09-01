#!/usr/bin/env python3

import openai
import readline
import os

# Configuration de l'API OpenAI
openai.api_key = os.getenv("OPENAI_API_KEY")

if not openai.api_key:
    print("Veuillez définir la variable d'environnement OPENAI_API_KEY")
    exit(1)

def chat_with_gpt(prompt):
    try:
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[{"role": "user", "content": prompt}]
        )
        return response.choices[0].message.content
    except Exception as e:
        return f"Erreur: {str(e)}"

def main():
    print("ChatGPT dans le terminal - Tapez 'quit' pour quitter")
    print("----------------------------------------")

    while True:
        try:
            user_input = input("Vous: ")
            if user_input.lower() in ['quit', 'exit', 'q']:
                break

            print("ChatGPT: ", end="", flush=True)
            response = chat_with_gpt(user_input)
            print(response)
            print()

        except KeyboardInterrupt:
            print("\nAu revoir!")
            break
        except EOFError:
            break

if __name__ == "__main__":
    main()
