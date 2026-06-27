#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <raylib.h>
#include "nodes.hpp"
using namespace std;

// Global Variables ************************************************************************

int const GridSize = 100;
int const maxWindowSize = 1000;
int const offsetX = 20;
int const offsetY = 20;
int cellSize;

const int WALL_CODE  = 298;
const int START_CODE = 299;
const int END_CODE   = 300;
const int PATH_CODE  = 301;

// Each BRAM word is 24 bits, laid out (MSB -> LSB) exactly as it was packed in hardware:
//   bits 23-15 (9 bits) : distance   -> bram_data.range(23, 15)
//   bits 14-8  (7 bits) : parentX    -> bram_data.range(14, 8)
//   bits 7-1   (7 bits) : parentY    -> bram_data.range(7, 1)
//   bit  0     (1 bit)  : visited    -> bram_data.range(0, 0)
const int BRAM_WORD_BITS = 24;

Nodes grid[GridSize][GridSize];
bool visited[GridSize][GridSize] = {false};

int startX = -1;
int startY = -1;
int endX = -1;
int endY = -1;

bool dataLoaded = false;
string loadError = "";

// Functions *******************************************************************************
void drawGrid();
bool loadBramInit(const char* filename);

// Main function ***************************************************************************
int main(int argc, char** argv){

    // Initialize every node to its default (empty) state, addressed by (x, y)
    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {
            grid[x][y] = Nodes(x, y, 0);
        }
    }

    // BRAM dump file: optional path on the command line, otherwise "bram_init.txt"
    const char* bramFile = (argc > 1) ? argv[1] : "bram_init.txt";
    dataLoaded = loadBramInit(bramFile);

    // Calculate cellSize to fit in max window size (same layout as the original app)
    cellSize = (maxWindowSize - offsetX * 2) / GridSize;
    int windowWidth = GridSize * cellSize + offsetX * 2;
    int windowHeight = GridSize * cellSize + offsetY * 2 + 40; // Extra space for status text
    InitWindow(windowWidth, windowHeight, "BRAM Grid Viewer");
    SetTargetFPS(60);

    // Build the status line shown at the bottom of the window
    string status;
    if(!dataLoaded){
        status = "Failed to load '" + string(bramFile) + "': " + loadError;
    } else {
        status = "BRAM snapshot '" + string(bramFile) + "' - Start: ";
        status += (startX != -1) ? ("(" + to_string(startX) + ", " + to_string(startY) + ")") : "none";
        status += "  End: ";
        status += (endX != -1) ? ("(" + to_string(endX) + ", " + to_string(endY) + ")") : "none";
        status += "  -  viewer only, close window to exit.";
    }

    // Main loop - just keep displaying the loaded snapshot, no editing, no solving
    while(!WindowShouldClose()){
        BeginDrawing();
        ClearBackground(BLACK);

        if(dataLoaded){
            drawGrid();
        }

        DrawText(status.c_str(), 10, windowHeight - 30, 14, WHITE);
        EndDrawing();
    }

    CloseWindow();
    return 0;
}

// Reads a BRAM initialization dump and reconstructs the grid from it.
// Each line is one 24-character binary string (one BRAM word).
// Node (x, y) lives at address 100*x + y, i.e. line (100*x + y) of the file,
// which matches grid[x][y] given GridSize == 100.
bool loadBramInit(const char* filename){
    ifstream file(filename);
    if(!file.is_open()){
        loadError = "could not open file";
        return false;
    }

    string line;
    int addr = 0;
    int total = GridSize * GridSize;

    while(getline(file, line)){
        // Trim potential trailing whitespace/CR
        while(!line.empty() && (line.back() == '\r' || line.back() == '\n' || line.back() == ' ')){
            line.pop_back();
        }
        if(line.empty()) continue;

        if((int)line.size() != BRAM_WORD_BITS){
            loadError = "line " + to_string(addr) + " is not " + to_string(BRAM_WORD_BITS) + " bits";
            return false;
        }
        if(addr >= total){
            // Extra lines beyond the grid size are ignored
            addr++;
            continue;
        }

        // 100*x + y == addr  =>  x = addr / GridSize, y = addr % GridSize
        int x = addr / GridSize;
        int y = addr % GridSize;

        try {
            int distance = stoi(line.substr(0, 9), nullptr, 2);   // bits 23-15
            int parentX  = stoi(line.substr(9, 7), nullptr, 2);    // bits 14-8
            int parentY  = stoi(line.substr(16, 7), nullptr, 2);   // bits 7-1
            int v        = line[23] - '0';                        // bit 0

            grid[x][y].setDistance(distance);
            grid[x][y].setParent(parentX, parentY);
            visited[x][y] = (v != 0);

            if(distance == START_CODE){ startX = x; startY = y; }
            if(distance == END_CODE)  { endX = x;   endY = y;   }
        } catch(...) {
            loadError = "could not parse line " + to_string(addr);
            return false;
        }

        addr++;
    }

    if(addr < total){
        loadError = "file has " + to_string(addr) + " lines, expected " + to_string(total);
        return false;
    }

    return true;
}

void drawGrid() {
    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {

            int distance = grid[x][y].getDistance();
            Color color;

            if (distance == START_CODE) {
                color = GREEN;
            } else if (distance == END_CODE) {
                color = RED;
            } else if (distance == WALL_CODE) {
                color = DARKGRAY;
            } else if( distance > 0 && distance < 298){
                color = ORANGE; // Visited nodes with a valid distance are orange
            } else {
                // Everything else (empty nodes, or any other recorded value) is gray
                color = GRAY;
            }

            // Draw filled square
            DrawRectangle(offsetX + x * cellSize,
                          offsetY + y * cellSize,
                          cellSize,
                          cellSize,
                          color);

            // Grid lines
            DrawRectangleLines(offsetX + x * cellSize,
                               offsetY + y * cellSize,
                               cellSize,
                               cellSize,
                               BLACK);
        }
    }
}
