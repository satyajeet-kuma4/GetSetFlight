import json
import time
from flask import Flask, request, jsonify
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import re

app = Flask(__name__)

chrome_binary_path = r"C:\Program Files (x86)\chrome-win64\chrome-win64\chrome.exe"
PATH = r"C:\Program Files (x86)\chromedriver.exe"


def checkDayPlusOne(departure, duration):
    # Extract departure hours & minutes safely
    departureHrs, departureMins = map(int, departure.split()[0].split(":"))
    
    # Convert PM correctly (except for 12 PM)
    if "PM" in departure and departureHrs != 12:
        departureHrs += 12
    elif "AM" in departure and departureHrs == 12:
        departureHrs = 0  # Convert "12 AM" to 0 hours
    
    # Extract duration hours & minutes
    match = re.search(r"(\d+)h\s*(\d*)m?", duration)
    if match:
        durationHrs = int(match.group(1))
        durationMins = int(match.group(2)) if match.group(2) else 0  # Handle no minutes case
    else:
        durationHrs, durationMins = 0, 0
    
    # Compute total hours
    total_hours = departureHrs + durationHrs + (departureMins + durationMins) // 60
    return total_hours >= 24

def extract_flight_info(flight_text):
    lines = flight_text.split("\n")
    airline = ""
    departure = ""
    departure_city = ""
    duration = ""
    stops = 0
    arrival = ""
    arrival_city = ""
    price = ""
    if lines[0] == "Includes Free Meal":
        lines = lines[1:]
    airline = lines[0]
    departure = f"{lines[1]} {lines[2]}"
    departure_city = lines[3]
    duration = lines[4]
    if "Non-Stop" in duration:
        stops = 0
    else :
        stops = int(duration.split(" Stop")[0].split("•")[1].strip())

    

    check = checkDayPlusOne(departure=departure, duration=duration)

    if stops:
        if check:
            arrival = f"{lines[6]} {lines[7]}"
            arrival_city = lines[9]
            price = lines[10]
        else:
            arrival = f"{lines[6]} {lines[7]}"
            arrival_city = lines[8]
            price = lines[9]
    else:
        if check:
            arrival = f"{lines[5]} {lines[6]}"
            arrival_city = lines[8]
            price = lines[9]
        else:
            arrival = f"{lines[5]} {lines[6]}"
            arrival_city = lines[7]
            price = lines[8]
    print(f"{airline} {departure} {departure_city} {duration} {stops} {arrival} {arrival_city} {price} \n")
    return {
        "airline": airline,
        "departure": departure,
        "departure_city": departure_city,
        "duration": duration,
        "stops": stops,
        "arrival": arrival,
        "arrival_city": arrival_city,
        "price": price
    }


def get_flight_details(src, dest, date):
    service = Service(PATH)
    options = webdriver.ChromeOptions()
    options.binary_location = chrome_binary_path
    options.add_argument("--headless")
    driver = webdriver.Chrome(service=service, options=options)
    
    try:
        url = f"https://tickets.paytm.com/flights/flightSearch/{src}/{dest}/1/0/0/E/{date}?referer=search"
        driver.get(url)
        
        wait = WebDriverWait(driver, 10)
        flights = wait.until(EC.presence_of_all_elements_located((By.CLASS_NAME, "CvUja")))
        
        formatted_flights = [extract_flight_info(flight.text) for flight in flights]
        
        driver.quit()
        return formatted_flights
    
    except Exception as e:
        driver.quit()
        return {"error": str(e)}

@app.route('/flights', methods=['POST'])
def fetch_flights():
    data = request.json
    src = data.get("source")
    dest = data.get("destination")
    date = data.get("date")
    
    if not src or not dest or not date:
        return jsonify({"error": "Missing required parameters"}), 400
    
    flight_data = get_flight_details(src, dest, date)
    return jsonify(flight_data)

if __name__ == '__main__':
    app.run(debug=True, port=5000)
