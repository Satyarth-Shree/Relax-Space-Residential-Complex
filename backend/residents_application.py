from mysql.connector.pooling import MySQLConnectionPool
from pwdlib import PasswordHash
from pydantic import BaseModel, Field, EmailStr
from typing import Literal
import time

residents_pool = MySQLConnectionPool(
    pool_name = "residents_pool",
    pool_size = 5,
    host = "localhost",
    user = "ENTER YOUR MYSQl USERNAME",
    password = "ENTER PASSWORD OF MYSQL USER",
    database = "ENTER DATABASE NAME"
)

class NewResidents(BaseModel):
    name: str
    gmail: EmailStr
    year_of_birth: int = Field(ge = 1920, le = 2026)
    month_of_birth: int = Field(ge = 1, le = 12)
    day_of_birth: int = Field(ge = 1, le = 31)

    aadhar_number: str = Field(r"^\d{12}$")
    phone_number: str = Field(r"^\d{10}$")
    address: str = Field(min_length = 5, max_length = 130)
    room_seater: Literal[
        "1 SEATER",
        "2 SEATER",
        "3 SEATER",
        "4 SEATER",
        "5 SEATER",
        "6 SEATER",
        "7 SEATER",
        "8 SEATER"
    ]
    password: str = Field(min_length = 8, max_length = 40)

def create_application_id(gmail: str):
    connection = residents_pool.get_connection()
    cursor = connection.cursor()

    query = "Select Application_number from APPLICANTS where Gmail = %s"
    values = (gmail,)
    cursor.execute(query, values)
    result = cursor.fetchall()

    application_number = result[0][0]
    year = time.localtime().tm_year
    application_id = "APP" + "-" + str(year) + "-" + str(application_number)

    query = "update APPLICANTS set Application_ID = %s where Application_number = %s"
    values = (application_id, application_number)
    cursor.execute(query, values)
    connection.commit()
    
    cursor.close()
    connection.close()
    
    

def create_password(gmail: str, password: str):
    connection = residents_pool.get_connection()
    cursor = connection.cursor()

    password_hash = PasswordHash.recommended()
    hashed_password = password_hash.hash(password)
    query = "update APPLICANTS set password_hash = %s where Gmail = %s"
    values = (hashed_password, gmail)

    cursor.execute(query, values)
    connection.commit()

    cursor.close()
    connection.close()


def create_application(application: NewResidents):
    connection = residents_pool.get_connection()
    cursor = connection.cursor()
    query = """
        insert into APPLICANTS
        (
            Name,
            Gmail,
            Year_of_birth,
            Month_of_birth,
            Day_of_birth,
            aadhar_number,
            phone_number,
            Address,
            Status,
            room_seater
        )
        values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    values = (
        application.name,
        application.gmail,
        application.year_of_birth,
        application.month_of_birth,
        application.day_of_birth,
        application.aadhar_number,
        application.phone_number,
        application.address,
        "UP",
        application.room_seater
    )

    cursor.execute(query, values)
    connection.commit()
    cursor.close()
    connection.close()

    create_application_id(application.gmail)
    create_password(application.gmail, application.password)

    return {
        "message": "Application creating in progress!"
    }

