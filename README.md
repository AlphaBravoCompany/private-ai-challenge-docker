# Private AI Challenge Docker

You have all likely just completed a day of container and Docker training and now you are wondering what you can do with this newfound super power.

How about deploying your own private "ChatGPT" complete with a locally running Large Language Model and a ChatGPT like Web UI.

This challenge will work through a few of the steps that you learned in the class and show you what is now possible that you have these skills.

Let's get started!

## Installing Ollama

1. Open the `./ollama` folder in this repo and copy the contents of the `docker-compose.yml` file
2. Log into you lab server and start a new lab environment
3. In the terminal, type `mkdir ollama`
4. `cd` into the Ollama directory and run `nano docker-compose.yml`
5. Paste in your copy of the `docker-compose.yml` file from step 1
6. Press `Ctrl+X` to exit and `Y` to save the file
7. Run `docker compose up -d` to start the Ollama server
8. Run `curl http://YOUR-SERVER-IP:11434` in a the terminal window and it should respond with "Ollama is running!"

## Downloading a LLM

1. In the terminal window run `docker exec -it ollama ollama pull gemma:2b`
2. Once the download completes run `docker exec -it ollama ollama ls` and confirm you see the `gemma:2b` model listed

## Installing OpenWebUI

1. Open the `./open-webui` folder in this repo and copy the contents of the `docker-compose.yml` file
2. In the terminal, type `mkdir open-webui`
3. `cd` into the OpenWebUI directory and run `nano docker-compose.yml`
4. Paste in your copy of the `docker-compose.yml` file from step 1.
5. Modify the `OLLAMA_URL` environment variable to point to your Ollama server. It should look like `OLLAMA_URL=http://YOUR-SERVER-IP:11434`
6. Press `Ctrl+X` to exit and `Y` to save the file
7. Run `docker compose up -d` to start the OpenWebUI server
8. Open a web browser and navigate to `http://YOUR-SERVER-IP:8080` and you should see the OpenWebUI login page
9. Create an account and login
10. You should now see the OpenWebUI dashboard. Select the `gemma:2b` model at the top of the screen and ask it a question in the message box at the bottom of the screen. (The response will be slow as this is only running on a small server and using CPU instead of GPU).

Congratulations! You have now deployed your own private "ChatGPT" like AI model and Web UI.