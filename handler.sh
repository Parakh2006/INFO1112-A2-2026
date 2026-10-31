#!/bin/bash

assignment_request() {
    url="https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC"

    if ! curl -fsSL "$url" -o /root/assignment.html; then
        echo "Error: Unable to download assignment webpage."
        return 1
    fi

    if ! html2text /root/assignment.html > /root/assignment.txt; then
        echo "Error: Unable to convert HTML into text."
        return 1
    fi

    if ! grep -i -A 2 "Assignment 2" /root/assignment.txt; then
        echo "Error: Assignment 2 information not found."
        return 1
    fi
}


read -r request

if [ "$request" = "assignment" ]; then
    assignment_request
else
    echo "Error: Unknown request."
fi
