from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import RedirectResponse
from pwdlib import PasswordHash
from residents_application import NewResidents
import residents_application 
import time
import secrets

app = FastAPI()


@app.post("/resident-application")
def resident_application(application: NewResidents):
    result = residents_application.create_application(application)
    return result


@app.get("/backend/room-seator")
def room_seator():
    return {
        "room_choices": [
            "1 SEATER",
            "2 SEATER",
            "3 SEATER",
            "4 SEATER",
            "5 SEATER",
            "6 SEATER",
            "7 SEATER",
            "8 SEATER"
        ]
    }

