#!/bin/bash

cfile=/opt/data/epweather/db/cities.txt
cdir=/opt/data/epweather/db/

function Help {

    echo -e "
    Usage: epweather [option] [city_name]
    Options:
      -a [city_name]    Add a new city
      -d [city_name]    Delete a city
      -l                List all cities
      -l [city_name]    List all data of cities
      -u                Update database
      -n [city_name]    Get current weather for a city without adding to database
      [city_name]       Get weather for a city (added to database if not already exists)
      -h                Show this help message
    "

}
getWeatherByName() {

    # try curl 3 times with 5 secound gap if curl gets error
    try=2
    while :; do
        sleep 5
        we=$(curl -s "wttr.in/${1}?format=j2")

        if [ ! $? = 0 ]; then
            if [ $try -ge 0 ]; then
                we=$(curl -s "wttr.in/${1}?format=j2")
            else
                echo "check intenet"
                exit
            fi
        else
            break
        fi
        try=$(($try - 1))
    done

    # extract data we need from json we curled
    tdate=$(date)
    country=$(jq -r .nearest_area[0].country[0].value <<<$we)
    city=$(jq -r .nearest_area[0].areaName[0].value <<<$we)
    temp=$(jq -r .current_condition[0].temp_C <<<$we)
    wdesc=$(jq -r .current_condition[0].weatherDesc[0].value <<<$we)
    windspeed=$(jq -r .current_condition[0].windspeedKmph <<<$we)
    humidity=$(jq -r .current_condition[0].humidity <<<$we)

    echo "${tdate}:${country}/${city}-${temp}C-${wdesc}-${windspeed}km-${humidity}%"

    return 0
}
getWeatherByNameFromDbOrWeb() {

    if [[ ! -z $1 ]]; then
        if echo "$1" | grep -i -q '^[a-z]*$'; then
            if grep -q "^$1\b" $cfile; then
                echo -e "Found in DB."
                tail -n 1 $cdir$1.txt
            else
                echo -e "Not Found in DB."
                getWeatherByName $1
            fi
            exit
        else
            echo "cityname (a-z) dont use (!@#$%^&*()... or numbers123..)"
            return 2
            exit
        fi
    fi

    return 0
}
function updateFunction {

    cities=($(cat $cfile))
    for city in ${cities[@]}; do

        getWeatherByName $city >>"${cdir}$city.txt"

    done

    return 0
}
function Append() {
    if [ ! -z $1 ]; then                  # check for argument
        if grep -q "^$1\b" "$cfile"; then # check for existance
            echo -e "Already exist."
        else
            echo $1 >>$cfile
            getWeatherByName $1 >>"${cdir}$1.txt"
            echo -e "Added."
        fi
    else
        echo -e "Error missed cityname"
        echo -e "-a [city_name]     Add a new city"
        return 2
    fi
    return 0
}
function ListDataOfCity() {
    if [[ ! -z $1 ]]; then # check for argument
        if echo $1 | grep -i -q '^[a-z]*$'; then
            if grep -q "^$1\b" "$cfile"; then
                awk '{ print NR , $0 }' $cdir$1.txt
                exit
            fi
            echo "Not found."
        else
            echo "cityname (a-z) dont use (!@#$%^&*()... or numbers123..)"
            return 2
            exit
        fi
    else
        awk '{ print NR , $0 }' $cfile
    fi
    return 0
}
function Delete() {
    if [ ! -z $1 ]; then # check for argument
        if grep -q "^$1\b" "$cfile"; then
            sed -i "/^$1\b/d" $cfile
            read -p "Also delete from databse ?(Y/n) : " Q
            if [[ $Q = "" ]]; then
                rm -f $cdir$1.txt
            fi
        else
            echo -e "City not found"
        fi
    else
        echo -e "Error missed cityname"
        echo -e "-d [city_name]     Delete city"
        return 2
    fi
    return 0
}
function getWeather() {
    if [[ ! -z $1 ]]; then # check for argument
        if echo $1 | grep -i -q '^[a-z]*$'; then
            # checkInDatabase
            getWeatherByName $1
            return 0
            exit
        else
            echo "cityname (a-z) dont use (!@#$%^&*()... or numbers123..)"
            return 2
            exit
        fi
    else
        echo -e "Error missed cityname"
        echo -e "-n [city_name]    Get current weather for a city without adding to database"
        return 2
    fi
}
optspec="aldnuhL"
while getopts "$optspec" optchar; do
    case "${optchar}" in
    a) Append $2 ;;
    l) ListDataOfCity $2 ;;
    d) Delete $2 ;;
    n) getWeather $2 ;;
    u) updateFunction ;;
    h) Help ;;
    *) Help ;;
    esac
    exit
done

if [ ! -z $1 ]; then
    getWeatherByNameFromDbOrWeb $1
fi
Help
