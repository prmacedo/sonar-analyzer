@echo off
setlocal
echo [Setup] Creating virtual environment...
python -m venv .venv

echo [Setup] Activating virtual environment...
call .venv\Scripts\activate

echo [Setup] Installing dependencies...
pip install --upgrade pip
pip install -r requirements.txt

echo [Setup] Running setup_sonar.py...
python setup_sonar.py

echo [Setup] Done! Your settings have been written to .env.
echo          You can now run run.bat to analyze your project.
endlocal
