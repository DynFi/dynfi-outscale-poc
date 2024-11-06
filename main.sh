#!/bin/sh

source config/config.sh
source config/colors.sh

yes_or_no() {
    local default_value=$1
    if [[ "$default_value" =~ ^[Yy]$ ]]; then
        echo "[Y/n]"
    else
        echo "[y/N]"
    fi
}

read -p "Do you want to build the flask omi POC? $(yes_or_no $DEFAULT_BUILD_FLASK_OMI): " ANSWER_BUILD_FLASK_OMI
read -p "Do you want to create a new updated flask OMI based on the last one? $(yes_or_no $DEFAULT_UPDATE_FLASK_OMI): " ANSWER_UPDATE_FLASK_OMI
read -p "Do you want to build the POC? $(yes_or_no $DEFAULT_BUILD_POC): " ANSWER_BUILD_POC


ANSWER_BUILD_FLASK_OMI=${ANSWER_BUILD_FLASK_OMI:-$DEFAULT_BUILD_FLASK_OMI}
START_TIME=$SECONDS
if [[ "$ANSWER_BUILD_FLASK_OMI" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Task BUILD_FLASK_OMI is being executed.${NC}"
    source scripts/make_flask_app.sh
else
    echo -e "${BLUE}Task BUILD_FLASK_OMI is skipped.${NC}"
fi
TIME_BUILD_FLASK_OMI=$(($SECONDS-$START_TIME))

ANSWER_UPDATE_FLASK_OMI=${ANSWER_UPDATE_FLASK_OMI:-$DEFAULT_UPDATE_FLASK_OMI}
START_TIME=$SECONDS
if [[ "$ANSWER_UPDATE_FLASK_OMI" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Task UPDATE_FLASK_OMI is being executed.${NC}"
    source scripts/create_updated_flask_omi_from_last_omi.sh
else
    echo -e "${BLUE}Task UPDATE_FLASK_OMI is skipped.${NC}"
fi
TIME_UPDATE_FLASK_OMI=$(($SECONDS-$START_TIME))

ANSWER_BUILD_POC=${ANSWER_BUILD_POC:-$DEFAULT_BUILD_POC}
START_TIME=$SECONDS
if [[ "$ANSWER_BUILD_POC" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Task BUILD_POC is being executed.${NC}"
    source scripts/build_poc.sh
else
    echo -e "${BLUE}Task BUILD_POC is skipped.${NC}"
fi
TIME_BUILD_POC=$(($SECONDS-$START_TIME))


echo -e "${GREEN}"
echo "Time spent on BUILD_FLASK_OMI: ${TIME_BUILD_FLASK_OMI} seconds"
echo "Time spent on UPDATE_FLASK_OMI: ${TIME_UPDATE_FLASK_OMI} seconds"
echo "Time spent on BUILD_POC: ${TIME_BUILD_POC} seconds"
echo ""
echo "Total : $(($TIME_BUILD_FLASK_OMI+$TIME_UPDATE_FLASK_OMI+$TIME_BUILD_POC)) seconds"
echo -e "${NC}"
