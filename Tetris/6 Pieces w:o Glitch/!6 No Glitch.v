`timescale 1ns / 1ps

module tetris(ClkPort, vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b, Sw0, Sw1, btnU, btnD, btnL, btnR, btnC,
    St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar);
    input ClkPort, Sw0, Sw1, btnU, btnD, btnL, btnR, btnC;
    output St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar;
    output vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b;

    reg vga_r, vga_g, vga_b;


    /*  LOCAL SIGNALS */
    wire    reset, start, ClkPort, board_clk, clk, button_clk;

    BUF BUF1 (board_clk, ClkPort);
    BUF BUF2 (reset, Sw0);
    BUF BUF3 (ACK, Sw1);

    reg [27:0]  DIV_CLK;
    always @ (posedge board_clk, posedge reset)
        begin : CLOCK_DIVIDER
            if (reset)
                DIV_CLK <= 0;
            else
                DIV_CLK <= DIV_CLK + 1'b1;
        end

    assign  button_clk = DIV_CLK[18];
    assign  clk = DIV_CLK[1];
    assign  {St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar} = {5'b11111};

    wire inDisplayArea;
    wire [9:0] CounterX;
    wire [9:0] CounterY;

    //stuff we added
    reg [4:0] piece;
    /* assigning row and col block variables: iterate through blocks of piece from top row to bottom row, left to right in each row */
    reg [4:0] rowfirstblock;
    reg [3:0] colfirstblock;
    reg [4:0] rowsecondblock;
    reg [3:0] colsecondblock;
    reg [4:0] rowthirdblock;
    reg [3:0] colthirdblock;
    reg [4:0] rowfourthblock;
    reg [3:0] colfourthblock;
    reg [4:0] numrowscleared;
    reg verticalcollisionmarker;
    reg lefthorizontalcollisionmarker;
    reg righthorizontalcollisionmarker;
    reg completerow;
    reg completerowcheck;
    reg completerowclear;
    reg gameovercheck;
    reg [2:0] state;
    reg [4:0] fallingbrake;
    reg [2:0] pieceselector;
    reg [4:0] toprowcleared;
    reg [4:0] horizontalbuttonstimer;
    reg pieceselectionflag;
    reg pauseactivated;
    wire ack;
    reg[4:0] j;
    reg[4:0] k;
    reg[4:0] a;
    reg[4:0] b;
    reg[4:0] e;

    // Initialize 2D array for  board, form is width then depth
    reg [9:0] board [22:0];

    // stuff for SCEN
    reg button_once;
    reg [2:0] scen_state;
    reg [4:0] debounce_count;

    localparam
        INITIAL = 3'b000,
        SELECT  = 3'b001,
        FALLING = 3'b010,
        LINES   = 3'b011,
        GAMEOVER= 3'b100,
        UNKNOWN = 3'bxxx,
        // SCEN States
        INI     = 3'b101,
        WQ      = 4'b110,
        SCEN_st = 4'b111;

    hvsync_generator syncgen(.clk(clk), .reset(reset),.vga_h_sync(vga_h_sync), .vga_v_sync(vga_v_sync), .inDisplayArea(inDisplayArea), .CounterX(CounterX), .CounterY(CounterY));

    //check for pause
    always @(posedge DIV_CLK[21], posedge reset)
        begin
            if (reset)
                begin
                    pauseactivated <= 0;
                end
            else if (btnC && button_once == 1'b1)
                begin
                    if (pauseactivated == 1)
                        begin
                            pauseactivated <= 0;
                        end
                    else if (pauseactivated == 0)
                        begin
                            pauseactivated <= 1;
                        end
                end
        end

    // random number generator
    always @(posedge DIV_CLK[21], posedge reset)
        begin
            if (reset)
                begin
                    fallingbrake <= 0;
                    pieceselector <= 0;
                end
            else
                begin
                    fallingbrake <= fallingbrake + 1'b1;
                    pieceselector <= pieceselector + rowfirstblock + colfirstblock;
                    //if fallingrake hits 15 reset to 0
                    if (fallingbrake == 5'd15)
                        begin
                            fallingbrake <= 0;
                        end
                    if (btnD && ~btnU)
                        begin
                            pieceselector <= pieceselector + 3'd1;
                        end
                    else if (btnU && ~btnD)
                        begin
                            pieceselector <= pieceselector + 3'd2;
                        end
                    else if (btnL && ~btnR)
                        begin
                            pieceselector <= pieceselector + 3'd3;
                        end
                    else if (btnR && ~btnL)
                        begin
                            pieceselector <= pieceselector + 3'd4;
                        end
                end
        end

    // sliding pieces
    always @(posedge DIV_CLK[21], posedge reset)
        begin
            if (reset)
                begin
                    horizontalbuttonstimer <= 5'b00000;
                end
            else
                begin
                    //if there is a collision, start counting up
                    if (verticalcollisionmarker == 1'b1)
                        begin
                            horizontalbuttonstimer <= horizontalbuttonstimer + 1'b1;
                        end
                    //if the counter reaches 21, reset back to 0
                    if (horizontalbuttonstimer == 5'd21)
                        begin
                            horizontalbuttonstimer <= 0;
                        end
                end
        end

    // disable button holds
    always @ (posedge DIV_CLK[21], posedge reset)
        begin : SCEN
            if (reset)
                begin
                  scen_state <= INI;
                  debounce_count <= 5'b0;
                  button_once <= 1'b0;
                end
            else
               begin
                    case (scen_state)
                        INI:
                            begin
                                debounce_count <= 0;
                                button_once <= 0;
                                if (btnD || btnU || btnL || btnR || btnC)
                                    begin
                                        scen_state <= WQ;
                                    end
                            end
                       WQ:
                            begin
                                debounce_count <= debounce_count + 1'b1;
                                if (~btnD && ~btnU && ~btnL && ~btnR && ~btnC)
                                    begin
                                        scen_state <= INI;
                                    end
                                else if (debounce_count == 5'd2)
                                    begin
                                        scen_state <= SCEN_st;
                                    end
                            end
                       SCEN_st:
                            begin
                                debounce_count <= 0;
                                button_once <= 1;
                                scen_state <= INI;
                            end
                    endcase
                end
        end

    /******************************************************************STATE MACHINE*************************************************************/
    /********************************************************************************************************************************************/
    /********************************************************************************************************************************************/

    /* CONTROL SIGNAL DOCUMENTATION

    completerow: if a row is all ones, completerow goes to 1
    gameovercheck: if there is a collision in rows 0 or 1, gameovercheck goes to 1
    verticalcollisionmarker: if box below falling piece is full, verticalcollisionmarker goes to 1
     */

    always @ (posedge DIV_CLK[21], posedge reset)
        begin
            if (reset)
                begin
                    state <= INITIAL;
                    piece <= 5'b00000;
                    rowfirstblock <= 5'b00000;
                    colfirstblock <= 4'b0000;
                    rowsecondblock <= 5'b00000;
                    colsecondblock <= 4'b0000;
                    rowthirdblock <= 5'b00000;
                    colthirdblock <= 4'b0000;
                    rowfourthblock <= 5'b00000;
                    colfourthblock <= 4'b0000;
                    pieceselectionflag <= 1'b0;
                    verticalcollisionmarker <= 1'b0;
                    lefthorizontalcollisionmarker <= 0;
                    righthorizontalcollisionmarker <= 0;
                    gameovercheck <= 1'b0;
                    numrowscleared <= 5'b00000;
                    completerow <= 1'b0;
                    toprowcleared <= 5'd0;
                end
            else
                begin
                    case (state)
                        INITIAL:
                            begin
                                // Transitions
                                // if(start)
                                    // begin
                                        state <= SELECT;
                                    // end
                                // RTL
                                pieceselectionflag <= 1'b0;
                                for (j = 0; j < 22; j = j + 1)
                                    for (k = 0; k < 10; k = k + 1)
                                        begin
                                            board[j][k] = 0;
                                        end

                                for (j = 0; j < 10; j = j + 1)
                                    board[22][j] = 1;
                            end
                        SELECT:
                            begin
                                verticalcollisionmarker = 1'b0;
                                // Transitions
                                if((piece[4:2] == 3'b001 || piece[4:2] == 3'b010 ||
                                    piece[4:2] == 3'b011 ||
                                    piece[4:2] == 3'b101 || piece[4:2] == 3'b110 ||
                                    piece[4:2] == 3'b111) && pieceselectionflag == 1'b1)
                                    begin
                                        pieceselectionflag = 1'b0;
                                        state <= FALLING;
                                    end
                                else
                                    begin
                                        // RTL
                                        piece[4:2] = pieceselector[2:0];
                                        // piece[4:2] = 3'b001;
                                        piece[1:0] = 2'b00;

                                        /* assigning row and col block variables: iterate through blocks of piece from top row to bottom row,
                                        left to right in each row */

                                        //if piece is long rectangle
                                        if (piece[4:2] == 3'b001)
                                            begin
                                                rowfirstblock = 5'd0;
                                                colfirstblock = 4'd5;
                                                rowsecondblock = 5'd1;
                                                colsecondblock = 4'd5;
                                                rowthirdblock = 5'd2;
                                                colthirdblock = 4'd5;
                                                rowfourthblock = 5'd3;
                                                colfourthblock = 4'd5;
                                                board[rowfirstblock][colfirstblock] = 1;
                                                board[rowsecondblock][colsecondblock] = 1;
                                                board[rowthirdblock][colthirdblock] = 1;
                                                board[rowfourthblock][colfourthblock] = 1;
                                                pieceselectionflag = 1'b1;
                                            end
                                        //if piece is right depressed z block
                                        else if (piece[4:2] == 3'b010)
                                            begin
                                                rowfirstblock = 5'd0;
                                                colfirstblock = 4'd4;
                                                rowsecondblock = 5'd1;
                                                colsecondblock = 4'd4;
                                                rowthirdblock = 5'd1;
                                                colthirdblock = 4'd5;
                                                rowfourthblock = 5'd2;
                                                colfourthblock = 4'd5;
                                                board[rowfirstblock][colfirstblock] = 1;
                                                board[rowsecondblock][colsecondblock] = 1;
                                                board[rowthirdblock][colthirdblock] = 1;
                                                board[rowfourthblock][colfourthblock] = 1;
                                                pieceselectionflag = 1'b1;
                                            end
                                        //if piece is left depressed z block
                                        else if (piece[4:2] == 3'b011)
                                            begin
                                                rowfirstblock = 5'd0;
                                                colfirstblock = 4'd5;
                                                rowsecondblock = 5'd1;
                                                colsecondblock = 4'd4;
                                                rowthirdblock = 5'd1;
                                                colthirdblock = 4'd5;
                                                rowfourthblock = 5'd2;
                                                colfourthblock = 4'd4;
                                                board[rowfirstblock][colfirstblock] = 1;
                                                board[rowsecondblock][colsecondblock] = 1;
                                                board[rowthirdblock][colthirdblock] = 1;
                                                board[rowfourthblock][colfourthblock] = 1;
                                                pieceselectionflag = 1'b1;
                                            end
                                        //if piece is T block
                                        // else if (piece[4:2] == 3'b100)
                                        //     begin
                                        //         rowfirstblock = 5'd0;
                                        //         colfirstblock = 4'd5;
                                        //         rowsecondblock = 5'd1;
                                        //         colsecondblock = 4'd4;
                                        //         rowthirdblock = 5'd1;
                                        //         colthirdblock = 4'd5;
                                        //         rowfourthblock = 5'd1;
                                        //         colfourthblock = 4'd6;
                                        //         board[rowfirstblock][colfirstblock] = 1;
                                        //         board[rowsecondblock][colsecondblock] = 1;
                                        //         board[rowthirdblock][colthirdblock] = 1;
                                        //         board[rowfourthblock][colfourthblock] = 1;
                                        //         pieceselectionflag = 1'b1;
                                        //     end
                                        //if piece is flipped L block
                                        else if (piece[4:2] == 3'b101)
                                            begin
                                                rowfirstblock = 5'd0;
                                                colfirstblock = 4'd5;
                                                rowsecondblock = 5'd1;
                                                colsecondblock = 4'd5;
                                                rowthirdblock = 5'd2;
                                                colthirdblock = 4'd4;
                                                rowfourthblock = 5'd2;
                                                colfourthblock = 4'd5;
                                                board[rowfirstblock][colfirstblock] = 1;
                                                board[rowsecondblock][colsecondblock] = 1;
                                                board[rowthirdblock][colthirdblock] = 1;
                                                board[rowfourthblock][colfourthblock] = 1;
                                                pieceselectionflag = 1'b1;
                                            end
                                        //if piece is L block
                                        else if (piece[4:2] == 3'b110)
                                            begin
                                                rowfirstblock = 5'd0;
                                                colfirstblock = 4'd5;
                                                rowsecondblock = 5'd1;
                                                colsecondblock = 4'd5;
                                                rowthirdblock = 5'd2;
                                                colthirdblock = 4'd5;
                                                rowfourthblock = 5'd2;
                                                colfourthblock = 4'd6;
                                                board[rowfirstblock][colfirstblock] = 1;
                                                board[rowsecondblock][colsecondblock] = 1;
                                                board[rowthirdblock][colthirdblock] = 1;
                                                board[rowfourthblock][colfourthblock] = 1;
                                                pieceselectionflag = 1'b1;
                                            end
                                        //if piece is square
                                        else if (piece[4:2] == 3'b111)
                                            begin
                                                rowfirstblock = 5'd0;
                                                colfirstblock = 4'd5;
                                                rowsecondblock = 5'd0;
                                                colsecondblock = 4'd6;
                                                rowthirdblock = 5'd1;
                                                colthirdblock = 4'd5;
                                                rowfourthblock = 5'd1;
                                                colfourthblock = 4'd6;
                                                board[rowfirstblock][colfirstblock] = 1;
                                                board[rowsecondblock][colsecondblock] = 1;
                                                board[rowthirdblock][colthirdblock] = 1;
                                                board[rowfourthblock][colfourthblock] = 1;
                                                pieceselectionflag = 1'b1;
                                            end
                                    end
                            end
                        FALLING:
                            begin
                                // Transitions
                                if(gameovercheck == 1'b1 && completerow == 1'b0)
                                    begin
                                        state <= GAMEOVER;
                                    end
                                if(verticalcollisionmarker == 1'b1 && completerow == 0 && gameovercheck == 1'b0 && horizontalbuttonstimer == 5'd20)
                                    begin
                                        state <= SELECT;
                                    end
                                // RTL
                                if(pauseactivated == 1'b0)
                                    begin
                                        //if piece is vertical long rectangle
                                        if (piece[4:0] == 5'b00100 || piece[4:0] == 5'b00110)
                                            begin
                                                if (board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is horizontal long rectangle
                                        else if (piece[4:0] == 5'b00101 || piece[4:0] == 5'b00111)
                                            begin
                                                if (board[rowfirstblock + 1][colfirstblock] == 1 || board[rowsecondblock + 1][colsecondblock] == 1 ||
                                                    board[rowthirdblock + 1][colthirdblock] == 1 || board[rowthirdblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is right depressed vertical z block
                                        else if (piece[4:0] == 5'b01000 || piece[4:0] == 5'b01010)
                                            begin
                                                if (board[rowsecondblock + 1][colsecondblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is right depressed horizontal z block
                                        else if (piece[4:0] == 5'b01001 || piece[4:0] == 5'b01011)
                                            begin
                                                if (board[rowsecondblock + 1][colsecondblock] == 1 || board[rowthirdblock + 1][colthirdblock] == 1 ||
                                                    board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end

                                        //if piece is left depressed vertical z block
                                        else if (piece[4:0] == 5'b01100 || piece[4:0] == 5'b01110)
                                            begin
                                                if (board[rowthirdblock + 1][colthirdblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is left depressed horizontal z block
                                        else if (piece[4:0] == 5'b01101 || piece[4:0] == 5'b01111)
                                            begin
                                                if (board[rowfirstblock + 1][colfirstblock] == 1 || board[rowthirdblock + 1][colthirdblock] == 1 ||
                                                    board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end

                                        //if piece is T up block
                                        // else if (piece[4:0] == 5'b10000)
                                        //     begin
                                        //         if (board[rowsecondblock + 1][colsecondblock] == 1 || board[rowthirdblock + 1][colthirdblock] == 1 ||
                                        //             board[rowfourthblock + 1][colfourthblock] == 1)
                                        //             begin
                                        //                 verticalcollisionmarker = 1'b1;
                                        //                 if (rowfirstblock < 5'd4)
                                        //                     begin
                                        //                         gameovercheck = 1'b1;
                                        //                     end
                                        //             end
                                        //         else
                                        //             begin
                                        //                 verticalcollisionmarker = 1'b0;
                                        //                 gameovercheck = 1'b0;
                                        //             end
                                        //     end
                                        // //if piece is T right block
                                        // else if (piece[4:0] == 5'b10001)
                                        //     begin
                                        //         if (board[rowthirdblock + 1][colthirdblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                        //             begin
                                        //                 verticalcollisionmarker = 1'b1;
                                        //                 if (rowfirstblock < 5'd4)
                                        //                     begin
                                        //                         gameovercheck = 1'b1;
                                        //                     end
                                        //             end
                                        //         else
                                        //             begin
                                        //                 verticalcollisionmarker = 1'b0;
                                        //                 gameovercheck = 1'b0;
                                        //             end
                                        //     end
                                        // //if piece is T down block
                                        // else if (piece[4:0] == 5'b10010)
                                        //     begin
                                        //         if (board[rowfirstblock + 1][colfirstblock] == 1 || board[rowthirdblock + 1][colthirdblock] == 1 ||
                                        //             board[rowfourthblock + 1][colfourthblock] == 1)
                                        //             begin
                                        //                 verticalcollisionmarker = 1'b1;
                                        //                 if (rowfirstblock < 5'd4)
                                        //                     begin
                                        //                         gameovercheck = 1'b1;
                                        //                     end
                                        //             end
                                        //         else
                                        //             begin
                                        //                 verticalcollisionmarker = 1'b0;
                                        //                 gameovercheck = 1'b0;
                                        //             end
                                        //     end
                                        // //if piece is T left block
                                        // else if (piece[4:0] == 5'b10011)
                                        //     begin
                                        //         if (board[rowsecondblock + 1][colsecondblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                        //             begin
                                        //                 verticalcollisionmarker = 1'b1;
                                        //                 if (rowfirstblock < 5'd4)
                                        //                     begin
                                        //                         gameovercheck = 1'b1;
                                        //                     end
                                        //             end
                                        //         else
                                        //             begin
                                        //                 verticalcollisionmarker = 1'b0;
                                        //                 gameovercheck = 1'b0;
                                        //             end
                                        //     end

                                        //if piece is flipped L left block
                                        else if (piece[4:0] == 5'b10100)
                                            begin
                                                if (board[rowthirdblock + 1][colthirdblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is flipped L up block
                                        else if (piece[4:0] == 5'b10101)
                                            begin
                                                if (board[rowsecondblock + 1][colsecondblock] == 1 || board[rowthirdblock + 1][colthirdblock] == 1 ||
                                                    board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is flipped L right block
                                        else if (piece[4:0] == 5'b10110)
                                            begin
                                                if (board[rowsecondblock + 1][colsecondblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is flipped L down block
                                        else if (piece[4:0] == 5'b10111)
                                            begin
                                                if (board[rowfirstblock + 1][colfirstblock] == 1 || board[rowsecondblock + 1][colsecondblock] == 1 ||
                                                    board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is L right block
                                        else if (piece[4:0] == 5'b11000)
                                            begin
                                                if (board[rowthirdblock + 1][colthirdblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is L down block
                                        else if (piece[4:0] == 5'b11001)
                                            begin
                                                if (board[rowsecondblock + 1][colsecondblock] == 1 || board[rowthirdblock + 1][colthirdblock] == 1 ||
                                                    board[rowfourthblock  + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is L left block
                                        else if (piece[4:0] == 5'b11010)
                                            begin
                                                if (board[rowfirstblock + 1][colfirstblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is L up block
                                        else if (piece[4:0] == 5'b11011)
                                            begin
                                                if (board[rowsecondblock + 1][colsecondblock] == 1 || board[rowthirdblock + 1][colthirdblock] == 1 ||
                                                    board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        //if piece is square
                                        else if (piece[4:0] == 5'b11100 || piece[4:0] == 5'b11101 || piece[4:0] == 5'b11110 || piece[4:0] == 5'b11111)
                                            begin
                                                if (board[rowthirdblock + 1][colthirdblock] == 1 || board[rowfourthblock + 1][colfourthblock] == 1)
                                                    begin
                                                        verticalcollisionmarker = 1'b1;
                                                        if (rowfirstblock < 5'd4)
                                                            begin
                                                                gameovercheck = 1'b1;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        verticalcollisionmarker = 1'b0;
                                                        gameovercheck = 1'b0;
                                                    end
                                            end
                                        else
                                            begin
                                                verticalcollisionmarker = 1'b0;
                                                gameovercheck = 1'b0;
                                            end
                                        //whenever there's a vertical collision, check if a row is full
                                        if (verticalcollisionmarker == 1'b1 && gameovercheck == 1'b0)
                                            begin
                                                for (a = 22; a >= 1; a = a - 1)
                                                    begin
                                                        completerowcheck = 1'b1;
                                                        for (b = 0; b < 10; b = b + 1)
                                                            begin
                                                                if (board[a - 1][b] == 0)
                                                                    begin
                                                                        completerowcheck = 0;
                                                                    end
                                                            end
                                                        if (completerowcheck == 1'b1)
                                                            begin
                                                                completerow = 1'b1;
                                                                toprowcleared = a - 1;
                                                                numrowscleared = numrowscleared + 5'd1;
                                                                for (e = 0; e < 10; e = e + 1)
                                                                    begin
                                                                        board[a - 1][e] = 0;
                                                                    end
                                                            end
                                                    end
                                            end
                                        //if the game isn't over and a row is complete, clear the row
                                        if (completerow == 1'b1 && gameovercheck == 1'b0)
                                            begin
                                                completerow = 1'b0;
                                                //now that the complete rows have been cleared, lower the stationary pieces
                                                for (a = 22; a >= 1; a = a - 1)
                                                    begin
                                                        for (b = 0; b < 10; b = b + 1)
                                                            begin
                                                                //if spot is occupied and above row clear, move it down
                                                                if (board[a - 1][b] == 1 && (a - 1) < toprowcleared)
                                                                    begin
                                                                        //clear square on grid
                                                                        board[a - 1][b] = 0;
                                                                        //lower square by number of rows cleared
                                                                        board[(a - 1) + numrowscleared][b] = 1;
                                                                    end
                                                            end
                                                    end
                                                toprowcleared = 5'd0;
                                            end
                                        if (completerow == 1'b0)
                                            begin
                                                numrowscleared = 5'd0;
                                                //automatic fall is top priority
                                                if(~btnD && (fallingbrake == 5'd15) && verticalcollisionmarker == 1'b0)
                                                    begin
                                                        board[rowfirstblock][colfirstblock] = 0;
                                                        board[rowsecondblock][colsecondblock] = 0;
                                                        board[rowthirdblock][colthirdblock] = 0;
                                                        board[rowfourthblock][colfourthblock] = 0;
                                                        rowfirstblock = rowfirstblock + 5'd1;
                                                        rowsecondblock = rowsecondblock + 5'd1;
                                                        rowthirdblock = rowthirdblock + 5'd1;
                                                        rowfourthblock = rowfourthblock + 5'd1;
                                                        board[rowfirstblock][colfirstblock] = 1;
                                                        board[rowsecondblock][colsecondblock] = 1;
                                                        board[rowthirdblock][colthirdblock] = 1;
                                                        board[rowfourthblock][colfourthblock] = 1;
                                                    end
                                                if(btnD && button_once == 1'b1 && ~btnU && verticalcollisionmarker == 1'b0)
                                                    begin
                                                        board[rowfirstblock][colfirstblock] = 0;
                                                        board[rowsecondblock][colsecondblock] = 0;
                                                        board[rowthirdblock][colthirdblock] = 0;
                                                        board[rowfourthblock][colfourthblock] = 0;
                                                        rowfirstblock = rowfirstblock + 5'd1;
                                                        rowsecondblock = rowsecondblock + 5'd1;
                                                        rowthirdblock = rowthirdblock + 5'd1;
                                                        rowfourthblock = rowfourthblock + 5'd1;
                                                        board[rowfirstblock][colfirstblock] = 1;
                                                        board[rowsecondblock][colsecondblock] = 1;
                                                        board[rowthirdblock][colthirdblock] = 1;
                                                        board[rowfourthblock][colfourthblock] = 1;
                                                    end
                                                //now check for horizontal collisions now that the autofall and manual downward fall have proceeded
                                                //if piece is vertical long rectangle
                                                if (piece[4:0] == 5'b00100 || piece[4:0] == 5'b00110)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                            board[rowthirdblock][colthirdblock - 1] == 1 || board[rowfourthblock][colfourthblock - 1] == 1 ||
                                                            colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is horizontal long rectangle
                                                else if (piece[4:0] == 5'b00101 || piece[4:0] == 5'b00111)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is right depressed vertical z block
                                                else if (piece[4:0] == 5'b01000 || piece[4:0] == 5'b01010)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock - 1] == 1 || colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is right depressed horizontal z block
                                                else if (piece[4:0] == 5'b01001 || piece[4:0] == 5'b01011)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowthirdblock][colthirdblock - 1] == 1 ||
                                                            colthirdblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end

                                                //if piece is left depressed vertical z block
                                                else if (piece[4:0] == 5'b01100 || piece[4:0] == 5'b01110)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock - 1] == 1 || colsecondblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is left depressed horizontal z block
                                                else if (piece[4:0] == 5'b01101 || piece[4:0] == 5'b01111)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowthirdblock][colthirdblock - 1] == 1 ||
                                                            colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end

                                                //if piece is T up block
                                                // else if (piece[4:0] == 5'b10000)
                                                //     begin
                                                //         if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                //             colsecondblock == 0)
                                                //             begin
                                                //                 lefthorizontalcollisionmarker = 1'b1;
                                                //             end
                                                //         else
                                                //             begin
                                                //                 lefthorizontalcollisionmarker = 1'b0;
                                                //             end
                                                //     end
                                                // //if piece is T right block
                                                // else if (piece[4:0] == 5'b10001)
                                                //     begin
                                                //         if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                //             board[rowfourthblock][colfourthblock - 1] == 1 || colfirstblock == 0)
                                                //             begin
                                                //                 lefthorizontalcollisionmarker = 1'b1;
                                                //             end
                                                //         else
                                                //             begin
                                                //                 lefthorizontalcollisionmarker = 1'b0;
                                                //             end
                                                //     end
                                                // //if piece is T down block
                                                // else if (piece[4:0] == 5'b10010)
                                                //     begin
                                                //         if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowfourthblock][colfourthblock - 1] == 1 ||
                                                //             colfirstblock == 0)
                                                //             begin
                                                //                 lefthorizontalcollisionmarker = 1'b1;
                                                //             end
                                                //         else
                                                //             begin
                                                //                 lefthorizontalcollisionmarker = 1'b0;
                                                //             end
                                                //     end
                                                // //if piece is T left block
                                                // else if (piece[4:0] == 5'b10011)
                                                //     begin
                                                //         if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                //             board[rowfourthblock][colfourthblock - 1] == 1 || colsecondblock == 0)
                                                //             begin
                                                //                 lefthorizontalcollisionmarker = 1'b1;
                                                //             end
                                                //         else
                                                //             begin
                                                //                 lefthorizontalcollisionmarker = 1'b0;
                                                //             end
                                                //     end

                                                //if piece is flipped L left block
                                                else if (piece[4:0] == 5'b10100)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                            board[rowthirdblock][colthirdblock - 1] == 1 || colthirdblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is flipped L up block
                                                else if (piece[4:0] == 5'b10101)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                            colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is flipped L right block
                                                else if (piece[4:0] == 5'b10110)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowthirdblock][colthirdblock - 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock - 1] == 1 || colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is flipped L down block
                                                else if (piece[4:0] == 5'b10111)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowfourthblock][colfourthblock - 1] == 1 ||
                                                            colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is L right block
                                                else if (piece[4:0] == 5'b11000)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                            board[rowthirdblock][colthirdblock - 1] == 1 || colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is L down block
                                                else if (piece[4:0] == 5'b11001)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowfourthblock][colfourthblock - 1] == 1 ||
                                                            colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is L left block
                                                else if (piece[4:0] == 5'b11010)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowthirdblock][colthirdblock - 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock - 1] == 1 || colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is L up block
                                                else if (piece[4:0] == 5'b11011)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowsecondblock][colsecondblock - 1] == 1 ||
                                                            colsecondblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is square
                                                else if (piece[4:0] == 5'b11100 || piece[4:0] == 5'b11101 || piece[4:0] == 5'b11110 || piece[4:0] == 5'b11111)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock - 1] == 1 || board[rowthirdblock][colthirdblock - 1] == 1 ||
                                                            colfirstblock == 0)
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                lefthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        lefthorizontalcollisionmarker = 1'b0;
                                                    end
                                                //now check for right horizontal collisions
                                                //if piece is vertical long rectangle
                                                if (piece[4:0] == 5'b00100 || piece[4:0] == 5'b00110)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowsecondblock][colsecondblock + 1] == 1 ||
                                                            board[rowthirdblock][colthirdblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                            colfirstblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is horizontal long rectangle
                                                else if (piece[4:0] == 5'b00101 || piece[4:0] == 5'b00111)
                                                    begin
                                                        if (board[rowfourthblock][colfourthblock + 1] == 1 || colfourthblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is right depressed vertical z block
                                                else if (piece[4:0] == 5'b01000 || piece[4:0] == 5'b01010)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowthirdblock][colthirdblock + 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock + 1] == 1 || colfourthblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is right depressed horizontal z block
                                                else if (piece[4:0] == 5'b01001 || piece[4:0] == 5'b01011)
                                                    begin
                                                        if (board[rowsecondblock][colsecondblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                            colsecondblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end

                                                //if piece is left depressed vertical z block
                                                else if (piece[4:0] == 5'b01100 || piece[4:0] == 5'b01110)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowthirdblock][colthirdblock + 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock + 1] == 1 || colfirstblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is left depressed horizontal z block
                                                else if (piece[4:0] == 5'b01101 || piece[4:0] == 5'b01111)
                                                    begin
                                                        if (board[rowsecondblock][colsecondblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] ||
                                                            colfourthblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end

                                                //if piece is T up block
                                                // else if (piece[4:0] == 5'b10000)
                                                //     begin
                                                //         if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                //             colfourthblock == 9)
                                                //             begin
                                                //                 righthorizontalcollisionmarker = 1'b1;
                                                //             end
                                                //         else
                                                //             begin
                                                //                 righthorizontalcollisionmarker = 1'b0;
                                                //             end
                                                //     end
                                                // //if piece is T right block
                                                // else if (piece[4:0] == 5'b10001)
                                                //     begin
                                                //         if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowthirdblock][colthirdblock + 1] == 1 ||
                                                //             board[rowfourthblock][colfourthblock + 1] == 1 || colthirdblock == 9)
                                                //             begin
                                                //                 righthorizontalcollisionmarker = 1'b1;
                                                //             end
                                                //         else
                                                //             begin
                                                //                 righthorizontalcollisionmarker = 1'b0;
                                                //             end
                                                //     end
                                                // //if piece is T down block
                                                // else if (piece[4:0] == 5'b10010)
                                                //     begin
                                                //         if (board[rowthirdblock][colthirdblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                //             colthirdblock == 9)
                                                //             begin
                                                //                 righthorizontalcollisionmarker = 1'b1;
                                                //             end
                                                //         else
                                                //             begin
                                                //                 righthorizontalcollisionmarker = 1'b0;
                                                //             end
                                                //     end
                                                // //if piece is T left block
                                                // else if (piece[4:0] == 5'b10011)
                                                //     begin
                                                //         if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowthirdblock][colthirdblock + 1] == 1 ||
                                                //             board[rowfourthblock][colfourthblock + 1] || colfirstblock == 9)
                                                //             begin
                                                //                 righthorizontalcollisionmarker = 1'b1;
                                                //             end
                                                //         else
                                                //             begin
                                                //                 righthorizontalcollisionmarker = 1'b0;
                                                //             end
                                                //     end

                                                //if piece is flipped L left block
                                                else if (piece[4:0] == 5'b10100)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowsecondblock][colsecondblock + 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock + 1] == 1 || colfirstblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is flipped L up block
                                                else if (piece[4:0] == 5'b10101)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                            colfourthblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is flipped L right block
                                                else if (piece[4:0] == 5'b10110)
                                                    begin
                                                        if (board[rowsecondblock][colsecondblock + 1] == 1 || board[rowthirdblock][colthirdblock + 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock + 1] == 1 || colsecondblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is flipped L down block
                                                else if (piece[4:0] == 5'b10111)
                                                    begin
                                                        if (board[rowthirdblock][colthirdblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                            colthirdblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is L right block
                                                else if (piece[4:0] == 5'b11000)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowsecondblock][colsecondblock + 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock + 1] == 1 || colfourthblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is L down block
                                                else if (piece[4:0] == 5'b11001)
                                                    begin
                                                        if (board[rowthirdblock][colthirdblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                            colthirdblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is L left block
                                                else if (piece[4:0] == 5'b11010)
                                                    begin
                                                        if (board[rowsecondblock][colsecondblock + 1] == 1 || board[rowthirdblock][colthirdblock + 1] == 1 ||
                                                            board[rowfourthblock][colfourthblock + 1] == 1 || colsecondblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is L up block
                                                else if (piece[4:0] == 5'b11011)
                                                    begin
                                                        if (board[rowfirstblock][colfirstblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                            colfirstblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                //if piece is square
                                                else if (piece[4:0] == 5'b11100 || piece[4:0] == 5'b11101 || piece[4:0] == 5'b11110 || piece[4:0] == 5'b11111)
                                                    begin
                                                        if (board[rowsecondblock][colsecondblock + 1] == 1 || board[rowfourthblock][colfourthblock + 1] == 1 ||
                                                            colsecondblock == 9)
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b1;
                                                            end
                                                        else
                                                            begin
                                                                righthorizontalcollisionmarker = 1'b0;
                                                            end
                                                    end
                                                else
                                                    begin
                                                        righthorizontalcollisionmarker = 1'b0;
                                                    end
                                                if(btnL && button_once == 1'b1 && ~btnR && lefthorizontalcollisionmarker == 1'b0 && horizontalbuttonstimer < 5'd20)
                                                    begin
                                                        board[rowfirstblock][colfirstblock] = 0;
                                                        board[rowsecondblock][colsecondblock] = 0;
                                                        board[rowthirdblock][colthirdblock] = 0;
                                                        board[rowfourthblock][colfourthblock] = 0;
                                                        colfirstblock = colfirstblock - 4'd1;
                                                        colsecondblock = colsecondblock - 4'd1;
                                                        colthirdblock = colthirdblock - 4'd1;
                                                        colfourthblock = colfourthblock - 4'd1;
                                                        board[rowfirstblock][colfirstblock] = 1;
                                                        board[rowsecondblock][colsecondblock] = 1;
                                                        board[rowthirdblock][colthirdblock] = 1;
                                                        board[rowfourthblock][colfourthblock] = 1;
                                                    end
                                                if(btnR && button_once == 1'b1 && ~btnL && righthorizontalcollisionmarker == 1'b0 && horizontalbuttonstimer < 5'd20)
                                                    begin
                                                        board[rowfirstblock][colfirstblock] = 0;
                                                        board[rowsecondblock][colsecondblock] = 0;
                                                        board[rowthirdblock][colthirdblock] = 0;
                                                        board[rowfourthblock][colfourthblock] = 0;
                                                        colfirstblock = colfirstblock + 4'd1;
                                                        colsecondblock = colsecondblock + 4'd1;
                                                        colthirdblock = colthirdblock + 4'd1;
                                                        colfourthblock = colfourthblock + 4'd1;
                                                        board[rowfirstblock][colfirstblock] = 1;
                                                        board[rowsecondblock][colsecondblock] = 1;
                                                        board[rowthirdblock][colthirdblock] = 1;
                                                        board[rowfourthblock][colfourthblock] = 1;
                                                    end
                                                /* Flip piece around. Reset the first block and the rest of the blocks can use it to form piece.
                                                Follow same block numbering heuristic as before. */
                                                if(btnU && button_once == 1'b1 && ~btnD && verticalcollisionmarker == 1'b0)
                                                    begin
                                                        //if piece is vertical long rectangle
                                                        if (piece[4:0] == 5'b00100 || piece[4:0] == 5'b00110)
                                                            begin
                                                                if (colfirstblock < 9 && colfirstblock > 1 && board[rowfirstblock][colfirstblock + 1] == 0
                                                                    && board[rowfirstblock][colfirstblock - 1] == 0 && board[rowfirstblock][colfirstblock - 2] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock - 2;
                                                                        rowsecondblock = rowfirstblock;
                                                                        colsecondblock = colfirstblock + 1;
                                                                        rowthirdblock = rowfirstblock;
                                                                        colthirdblock = colsecondblock + 1;
                                                                        rowfourthblock = rowfirstblock;
                                                                        colfourthblock = colthirdblock + 1;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is horizontal long rectangle
                                                        else if (piece[4:0] == 5'b00101 || piece[4:0] == 5'b00111)
                                                            begin
                                                                if (rowfirstblock < 19 && board[rowthirdblock + 1][colthirdblock] == 0
                                                                    && board[rowthirdblock + 2][colthirdblock] == 0 && board[rowthirdblock + 3][colthirdblock] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colthirdblock;
                                                                        rowsecondblock = rowfirstblock + 1;
                                                                        colsecondblock = colfirstblock;
                                                                        rowthirdblock = rowsecondblock + 1;
                                                                        colthirdblock = colfirstblock;
                                                                        rowfourthblock = rowthirdblock + 1;
                                                                        colfourthblock = colfirstblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is right depressed vertical z block
                                                        else if (piece[4:0] == 5'b01000 || piece[4:0] == 5'b01010)
                                                            begin
                                                                if (colfirstblock > 0 && board[rowsecondblock][colsecondblock - 1] == 0 &&
                                                                    board[rowfirstblock][colfirstblock + 1] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock;
                                                                        rowsecondblock = rowfirstblock;
                                                                        colsecondblock = colfirstblock + 1;
                                                                        rowthirdblock = rowfirstblock + 1;
                                                                        colthirdblock = colfirstblock - 1;
                                                                        rowfourthblock = rowfirstblock + 1;
                                                                        colfourthblock = colfirstblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is right depressed horizontal z block
                                                        else if (piece[4:0] == 5'b01001 || piece[4:0] == 5'b01011)
                                                            begin
                                                                if (rowfourthblock < 21 && board[rowfourthblock][colfourthblock + 1] == 0 &&
                                                                    board[rowfourthblock + 1][colfourthblock + 1] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock;
                                                                        rowsecondblock = rowfirstblock + 1;
                                                                        colsecondblock = colfirstblock;
                                                                        rowthirdblock = rowsecondblock;
                                                                        colthirdblock = colsecondblock + 1;
                                                                        rowfourthblock = rowthirdblock + 1;
                                                                        colfourthblock = colthirdblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end

                                                        //if piece is left depressed vertical z block
                                                        else if (piece[4:0] == 5'b01100 || piece[4:0] == 5'b01110)
                                                            begin
                                                                if (colsecondblock > 0 && board[rowfirstblock][colfirstblock - 2] == 0 &&
                                                                    board[rowfirstblock][colfirstblock - 1] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock - 2;
                                                                        rowsecondblock = rowfirstblock;
                                                                        colsecondblock = colfirstblock + 1;
                                                                        rowthirdblock = rowsecondblock + 1;
                                                                        colthirdblock = colsecondblock;
                                                                        rowfourthblock = rowthirdblock;
                                                                        colfourthblock = colthirdblock + 1;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is left depressed horizontal z block
                                                        else if (piece[4:0] == 5'b01101 || piece[4:0] == 5'b01111)
                                                            begin
                                                                if (rowfirstblock > 0 && board[rowfirstblock - 1][colfirstblock + 2] == 0 &&
                                                                    board[rowfirstblock][colfirstblock + 2] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock - 1;
                                                                        colfirstblock = colfirstblock + 2;
                                                                        rowsecondblock = rowfirstblock + 1;
                                                                        colsecondblock = colfirstblock - 1;
                                                                        rowthirdblock = rowfirstblock + 1;
                                                                        colthirdblock = colfirstblock;
                                                                        rowfourthblock = rowsecondblock + 1;
                                                                        colfourthblock = colsecondblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is T up block
                                                        // else if (piece[4:0] == 5'b10000)
                                                        //     begin
                                                        //         if (rowsecondblock < 21 && board[rowthirdblock + 1][colthirdblock] == 0)
                                                        //             begin
                                                        //                 board[rowfirstblock][colfirstblock] = 0;
                                                        //                 board[rowsecondblock][colsecondblock] = 0;
                                                        //                 board[rowthirdblock][colthirdblock] = 0;
                                                        //                 board[rowfourthblock][colfourthblock] = 0;
                                                        //                 piece[1:0] = piece[1:0] + 2'b01;
                                                        //                 rowfirstblock = rowfirstblock;
                                                        //                 colfirstblock = colfirstblock;
                                                        //                 rowsecondblock = rowfirstblock + 1;
                                                        //                 colsecondblock = colfirstblock;
                                                        //                 rowthirdblock = rowsecondblock;
                                                        //                 colthirdblock = colsecondblock + 1;
                                                        //                 rowfourthblock = rowsecondblock + 1;
                                                        //                 colfourthblock = colsecondblock;
                                                        //                 board[rowfirstblock][colfirstblock] = 1;
                                                        //                 board[rowsecondblock][colsecondblock] = 1;
                                                        //                 board[rowthirdblock][colthirdblock] = 1;
                                                        //                 board[rowfourthblock][colfourthblock] = 1;
                                                        //             end
                                                        //     end
                                                        // //if piece is T right block
                                                        // else if (piece[4:0] == 5'b10001)
                                                        //     begin
                                                        //         if (colfirstblock > 0 && board[rowsecondblock][colsecondblock - 1] == 0)
                                                        //             begin
                                                        //                 board[rowfirstblock][colfirstblock] = 0;
                                                        //                 board[rowsecondblock][colsecondblock] = 0;
                                                        //                 board[rowthirdblock][colthirdblock] = 0;
                                                        //                 board[rowfourthblock][colfourthblock] = 0;
                                                        //                 piece[1:0] = piece[1:0] + 2'b01;
                                                        //                 rowfirstblock = rowsecondblock;
                                                        //                 colfirstblock = colsecondblock - 1;
                                                        //                 rowsecondblock = rowsecondblock;
                                                        //                 colsecondblock = colsecondblock;
                                                        //                 rowthirdblock = rowthirdblock;
                                                        //                 colthirdblock = colthirdblock;
                                                        //                 rowfourthblock = rowfourthblock;
                                                        //                 colfourthblock = colfourthblock;
                                                        //                 board[rowfirstblock][colfirstblock] = 1;
                                                        //                 board[rowsecondblock][colsecondblock] = 1;
                                                        //                 board[rowthirdblock][colthirdblock] = 1;
                                                        //                 board[rowfourthblock][colfourthblock] = 1;
                                                        //             end
                                                        //     end
                                                        // //if piece is T down block
                                                        // else if (piece[4:0] == 5'b10010)
                                                        //     begin
                                                        //         if (rowfirstblock > 0 && board[rowsecondblock - 1][colsecondblock] == 0)
                                                        //             begin
                                                        //                 board[rowfirstblock][colfirstblock] = 0;
                                                        //                 board[rowsecondblock][colsecondblock] = 0;
                                                        //                 board[rowthirdblock][colthirdblock] = 0;
                                                        //                 board[rowfourthblock][colfourthblock] = 0;
                                                        //                 piece[1:0] = piece[1:0] + 2'b01;
                                                        //                 rowfirstblock = rowsecondblock - 1;
                                                        //                 colfirstblock = colsecondblock;
                                                        //                 rowsecondblock = rowfirstblock + 1;
                                                        //                 colsecondblock = colfirstblock - 1;
                                                        //                 rowthirdblock = rowsecondblock;
                                                        //                 colthirdblock = colfirstblock;
                                                        //                 rowfourthblock = rowthirdblock + 1;
                                                        //                 colfourthblock = colthirdblock;
                                                        //                 board[rowfirstblock][colfirstblock] = 1;
                                                        //                 board[rowsecondblock][colsecondblock] = 1;
                                                        //                 board[rowthirdblock][colthirdblock] = 1;
                                                        //                 board[rowfourthblock][colfourthblock] = 1;
                                                        //             end
                                                        //     end
                                                        // //if piece is T left block
                                                        // else if (piece[4:0] == 5'b10011)
                                                        //     begin
                                                        //         if (colfirstblock < 9 && board[rowthirdblock][colthirdblock + 1] == 0)
                                                        //             begin
                                                        //                 board[rowfirstblock][colfirstblock] = 0;
                                                        //                 board[rowsecondblock][colsecondblock] = 0;
                                                        //                 board[rowthirdblock][colthirdblock] = 0;
                                                        //                 board[rowfourthblock][colfourthblock] = 0;
                                                        //                 piece[1:0] = piece[1:0] + 2'b01;
                                                        //                 rowfirstblock = rowfirstblock;
                                                        //                 colfirstblock = colfirstblock;
                                                        //                 rowsecondblock = rowsecondblock;
                                                        //                 colsecondblock = colsecondblock;
                                                        //                 rowthirdblock = rowthirdblock;
                                                        //                 colthirdblock = colthirdblock;
                                                        //                 rowfourthblock = rowthirdblock;
                                                        //                 colfourthblock = colthirdblock + 1;
                                                        //                 board[rowfirstblock][colfirstblock] = 1;
                                                        //                 board[rowsecondblock][colsecondblock] = 1;
                                                        //                 board[rowthirdblock][colthirdblock] = 1;
                                                        //                 board[rowfourthblock][colfourthblock] = 1;
                                                        //             end
                                                        //     end

                                                        //if piece is flipped L left block
                                                        else if (piece[4:0] == 5'b10100)
                                                            begin
                                                                if (colfirstblock < 9 && board[rowsecondblock][colsecondblock - 1] == 0 &&
                                                                    board[rowfourthblock][colfourthblock + 1] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowsecondblock;
                                                                        colfirstblock = colsecondblock - 1;
                                                                        rowsecondblock = rowfirstblock + 1;
                                                                        colsecondblock = colfirstblock;
                                                                        rowthirdblock = rowsecondblock;
                                                                        colthirdblock = colsecondblock + 1;
                                                                        rowfourthblock = rowthirdblock;
                                                                        colfourthblock = colthirdblock + 1;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is flipped L up block
                                                        else if (piece[4:0] == 5'b10101)
                                                            begin
                                                                if (rowsecondblock < 21 && board[rowthirdblock - 1][colthirdblock] == 0 &&
                                                                    board[rowfourthblock - 1][colfourthblock] == 0 && board[rowthirdblock + 1][colthirdblock] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock + 1;
                                                                        rowsecondblock = rowfirstblock;
                                                                        colsecondblock = colfirstblock + 1;
                                                                        rowthirdblock = rowthirdblock;
                                                                        colthirdblock = colthirdblock;
                                                                        rowfourthblock = rowthirdblock + 1;
                                                                        colfourthblock = colthirdblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is flipped L right block
                                                        else if (piece[4:0] == 5'b10110)
                                                            begin
                                                                if (colfirstblock > 0 && board[rowfirstblock][colfirstblock - 1] == 0 &&
                                                                    board[rowsecondblock + 1][colsecondblock] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock - 1;
                                                                        rowsecondblock = rowfirstblock;
                                                                        colsecondblock = colfirstblock + 1;
                                                                        rowthirdblock = rowsecondblock;
                                                                        colthirdblock = colsecondblock + 1;
                                                                        rowfourthblock = rowthirdblock + 1;
                                                                        colfourthblock = colthirdblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is flipped L down block
                                                        else if (piece[4:0] == 5'b10111)
                                                            begin
                                                                if (rowfirstblock > 0 && board[rowsecondblock + 1][colsecondblock] == 0 &&
                                                                    board[rowsecondblock - 1][colsecondblock] == 0 && board[rowfirstblock + 1][colfirstblock] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock - 1;
                                                                        colfirstblock = colfirstblock + 1;
                                                                        rowsecondblock = rowsecondblock;
                                                                        colsecondblock = colsecondblock;
                                                                        rowthirdblock = rowsecondblock + 1;
                                                                        colthirdblock = colsecondblock - 1;
                                                                        rowfourthblock = rowthirdblock;
                                                                        colfourthblock = colsecondblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is L right block
                                                        else if (piece[4:0] == 5'b11000)
                                                            begin
                                                                if (colfirstblock > 0 && board[rowfirstblock][colfirstblock - 1] == 0 &&
                                                                    board[rowsecondblock][colsecondblock - 1] == 0 && board[rowfirstblock][colfirstblock + 1] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock - 1;
                                                                        rowsecondblock = rowfirstblock;
                                                                        colsecondblock = colfirstblock + 1;
                                                                        rowthirdblock = rowsecondblock;
                                                                        colthirdblock = colsecondblock + 1;
                                                                        rowfourthblock = rowfirstblock + 1;
                                                                        colfourthblock = colfirstblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is L down block
                                                        else if (piece[4:0] == 5'b11001)
                                                            begin
                                                                if (rowfourthblock < 21 && board[rowthirdblock + 1][colthirdblock] == 0 &&
                                                                    board[rowthirdblock + 2][colthirdblock] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock + 1;
                                                                        rowsecondblock = rowfirstblock;
                                                                        colsecondblock = colfirstblock + 1;
                                                                        rowthirdblock = rowsecondblock + 1;
                                                                        colthirdblock = colsecondblock;
                                                                        rowfourthblock = rowthirdblock + 1;
                                                                        colfourthblock = colsecondblock;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is L left block
                                                        else if (piece[4:0] == 5'b11010)
                                                            begin
                                                                if (colfirstblock > 0 && board[rowfirstblock + 1][colfirstblock] == 0 &&
                                                                    board[rowthirdblock][colthirdblock - 2] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock + 1;
                                                                        rowsecondblock = rowfirstblock + 1;
                                                                        colsecondblock = colfirstblock - 2;
                                                                        rowthirdblock = rowsecondblock;
                                                                        colthirdblock = colsecondblock + 1;
                                                                        rowfourthblock = rowthirdblock;
                                                                        colfourthblock = colthirdblock + 1;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                        //if piece is L up block
                                                        else if (piece[4:0] == 5'b11011)
                                                            begin
                                                                if (rowthirdblock < 21 && board[rowfirstblock][colfirstblock - 1] == 0 &&
                                                                    board[rowthirdblock + 1][colthirdblock] == 0 && board[rowfourthblock + 1][colfourthblock] == 0)
                                                                    begin
                                                                        board[rowfirstblock][colfirstblock] = 0;
                                                                        board[rowsecondblock][colsecondblock] = 0;
                                                                        board[rowthirdblock][colthirdblock] = 0;
                                                                        board[rowfourthblock][colfourthblock] = 0;
                                                                        piece[1:0] = piece[1:0] + 2'b01;
                                                                        rowfirstblock = rowfirstblock;
                                                                        colfirstblock = colfirstblock - 1;
                                                                        rowsecondblock = rowfirstblock + 1;
                                                                        colsecondblock = colfirstblock;
                                                                        rowthirdblock = rowsecondblock + 1;
                                                                        colthirdblock = colsecondblock;
                                                                        rowfourthblock = rowthirdblock;
                                                                        colfourthblock = colthirdblock + 1;
                                                                        board[rowfirstblock][colfirstblock] = 1;
                                                                        board[rowsecondblock][colsecondblock] = 1;
                                                                        board[rowthirdblock][colthirdblock] = 1;
                                                                        board[rowfourthblock][colfourthblock] = 1;
                                                                    end
                                                            end
                                                    end
                                                //if the block can no longer fall, stop
                                                if(verticalcollisionmarker == 1'b1)
                                                    begin
                                                        // stop movement
                                                    end
                                            end
                                    end
                            end
                        GAMEOVER:
                            begin
                                // Transitions
                                // if(Sw1 && button_once == 1'b1)
                                //     begin
                                //         state <= INITIAL;
                                //     end
                                // RTL
                                // for (f = 0; f < 22; f = f + 1)
                                //  for (g = 0; g < 10; g = g + 1)
                                //      begin
                                //          board[f][g] = 0;
                                //      end
                            end
                    endcase
                end
        end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////     VGA control starts here     ////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //640 wide
    //480 tall
    //20x20 pieces
    //position is reference point for other pixels, can describe shape
    reg [9:0] yposition;
    reg [9:0] xposition;
    reg [9:0] squarewidth;

    //this always block will add the current block to the right tempstorage wire when it is in place
    always @(posedge DIV_CLK[21])
        begin
            yposition <= 20;
            xposition <= 220;
            squarewidth <= 20;
        end


    //counter Y and counter X, tell monitor in this area all pixels red
    //counter Y> is upper bound of red area, counterY< is lower bound of red area, smaller value always above
    //counter x here is fixed horizontally
    //rgb all shared amongst pixels, treat wires as statements
    wire R =
        //    (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[0][0])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[0][1])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[0][2])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[0][3])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[0][4])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[0][5])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[0][6])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[0][7])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[0][8])
        // || (CounterY>(yposition + squarewidth*0) && CounterY<(yposition + squarewidth*1) &&
        //         CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[0][9])

        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[1][0])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[1][1])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[1][2])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[1][3])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[1][4])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[1][5])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[1][6])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[1][7])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[1][8])
        // || (CounterY>(yposition + squarewidth*1) && CounterY<(yposition + squarewidth*2) &&
        //         CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[1][9])

           (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[2][0])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[2][1])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[2][2])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[2][3])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[2][4])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[2][5])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[2][6])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[2][7])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[2][8])
        || (CounterY>(yposition + squarewidth*2) && CounterY<(yposition + squarewidth*3) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[2][9])

        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[3][0])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[3][1])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[3][2])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[3][3])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[3][4])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[3][5])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[3][6])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[3][7])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[3][8])
        || (CounterY>(yposition + squarewidth*3) && CounterY<(yposition + squarewidth*4) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[3][9])

        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[4][0])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[4][1])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[4][2])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[4][3])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[4][4])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[4][5])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[4][6])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[4][7])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[4][8])
        || (CounterY>(yposition + squarewidth*4) && CounterY<(yposition + squarewidth*5) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[4][9])

        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[5][0])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[5][1])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[5][2])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[5][3])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[5][4])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[5][5])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[5][6])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[5][7])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[5][8])
        || (CounterY>(yposition + squarewidth*5) && CounterY<(yposition + squarewidth*6) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[5][9])


        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[6][0])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[6][1])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[6][2])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[6][3])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[6][4])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[6][5])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[6][6])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[6][7])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[6][8])
        || (CounterY>(yposition + squarewidth*6) && CounterY<(yposition + squarewidth*7) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[6][9])

        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[7][0])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[7][1])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[7][2])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[7][3])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[7][4])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[7][5])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[7][6])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[7][7])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[7][8])
        || (CounterY>(yposition + squarewidth*7) && CounterY<(yposition + squarewidth*8) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[7][9])

        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[8][0])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[8][1])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[8][2])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[8][3])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[8][4])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[8][5])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[8][6])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[8][7])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[8][8])
        || (CounterY>(yposition + squarewidth*8) && CounterY<(yposition + squarewidth*9) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[8][9])

        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[9][0])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[9][1])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[9][2])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[9][3])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[9][4])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[9][5])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[9][6])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[9][7])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[9][8])
        || (CounterY>(yposition + squarewidth*9) && CounterY<(yposition + squarewidth*10) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[9][9])

        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[10][0])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[10][1])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[10][2])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[10][3])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[10][4])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[10][5])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[10][6])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[10][7])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[10][8])
        || (CounterY>(yposition + squarewidth*10) && CounterY<(yposition + squarewidth*11) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[10][9])

        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[11][0])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[11][1])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[11][2])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[11][3])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[11][4])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[11][5])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[11][6])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[11][7])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[11][8])
        || (CounterY>(yposition + squarewidth*11) && CounterY<(yposition + squarewidth*12) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[11][9])

        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[12][0])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[12][1])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[12][2])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[12][3])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[12][4])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[12][5])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[12][6])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[12][7])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[12][8])
        || (CounterY>(yposition + squarewidth*12) && CounterY<(yposition + squarewidth*13) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[12][9])

        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[13][0])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[13][1])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[13][2])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[13][3])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[13][4])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[13][5])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[13][6])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[13][7])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[13][8])
        || (CounterY>(yposition + squarewidth*13) && CounterY<(yposition + squarewidth*14) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[13][9])

        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[14][0])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[14][1])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[14][2])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[14][3])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[14][4])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[14][5])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[14][6])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[14][7])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[14][8])
        || (CounterY>(yposition + squarewidth*14) && CounterY<(yposition + squarewidth*15) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[14][9])

        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[15][0])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[15][1])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[15][2])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[15][3])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[15][4])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[15][5])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[15][6])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[15][7])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[15][8])
        || (CounterY>(yposition + squarewidth*15) && CounterY<(yposition + squarewidth*16) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[15][9])

        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[16][0])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[16][1])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[16][2])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[16][3])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[16][4])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[16][5])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[16][6])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[16][7])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[16][8])
        || (CounterY>(yposition + squarewidth*16) && CounterY<(yposition + squarewidth*17) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[16][9])

        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[17][0])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[17][1])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[17][2])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[17][3])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[17][4])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[17][5])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[17][6])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[17][7])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[17][8])
        || (CounterY>(yposition + squarewidth*17) && CounterY<(yposition + squarewidth*18) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[17][9])

        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[18][0])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[18][1])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[18][2])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[18][3])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[18][4])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[18][5])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[18][6])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[18][7])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[18][8])
        || (CounterY>(yposition + squarewidth*18) && CounterY<(yposition + squarewidth*19) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[18][9])

        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[19][0])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[19][1])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[19][2])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[19][3])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[19][4])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[19][5])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[19][6])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[19][7])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[19][8])
        || (CounterY>(yposition + squarewidth*19) && CounterY<(yposition + squarewidth*20) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[19][9])

        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[20][0])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[20][1])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[20][2])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[20][3])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[20][4])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[20][5])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[20][6])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[20][7])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[20][8])
        || (CounterY>(yposition + squarewidth*20) && CounterY<(yposition + squarewidth*21) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[20][9])

        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[21][0])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[21][1])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[21][2])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[21][3])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[21][4])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[21][5])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[21][6])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[21][7])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[21][8])
        || (CounterY>(yposition + squarewidth*21) && CounterY<(yposition + squarewidth*22) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[21][9]);

    wire G = (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*0) && CounterX<(xposition + squarewidth*1) && board[22][0])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*1) && CounterX<(xposition + squarewidth*2) && board[22][1])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*2) && CounterX<(xposition + squarewidth*3) && board[22][2])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*3) && CounterX<(xposition + squarewidth*4) && board[22][3])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*4) && CounterX<(xposition + squarewidth*5) && board[22][4])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*5) && CounterX<(xposition + squarewidth*6) && board[22][5])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*6) && CounterX<(xposition + squarewidth*7) && board[22][6])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*7) && CounterX<(xposition + squarewidth*8) && board[22][7])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*8) && CounterX<(xposition + squarewidth*9) && board[22][8])
        || (CounterY>(yposition + squarewidth*22) && CounterY<(yposition + squarewidth*23) &&
                CounterX>(xposition + squarewidth*9) && CounterX<(xposition + squarewidth*10) && board[22][9]

        || (CounterY>60 && CounterY<480 && CounterX<220 && CounterX>200)
        || (CounterY>60 && CounterY<480 && CounterX>420 && CounterX<440)

        );


    wire B = 0;

    //actually draw the wires through vga
    always @(posedge clk)
    begin
        vga_r <= R & inDisplayArea;
        vga_g <= G & inDisplayArea;
        vga_b <= B & inDisplayArea;
    end

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////        VGA control ends here      ////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
endmodule
