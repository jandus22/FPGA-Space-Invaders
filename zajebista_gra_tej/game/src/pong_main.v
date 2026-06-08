module pong_main
#(
  parameter SCR_W = 64,
  parameter SCR_H = 40,
  parameter PLAYER_W = 5,
  parameter PLAYER_H = 3,
  parameter ALIEN_W = 3,
  parameter ALIEN_H = 3,
  parameter SHOOT_RATE = 10_000, 
  parameter BULLET_SPEED = 800,
  // ZEGARY DLA DEMO
  //parameter MENU_WAIT_TIME = 50_000, // Na płytkę FPGA zmień na: 375_000_000 (5 sekund przy zegarze 75MHz)
  //parameter DEMO_LOOP_TIME = 100_000 // Na płytkę FPGA zmień na: 750_000_000 (10 sekund przy zegarze 75MHz)
  parameter MENU_WAIT_TIME = 400_000, // Na płytkę FPGA zmień na: 375_000_000 (5 sekund przy zegarze 75MHz)
  parameter DEMO_LOOP_TIME = 800_000 // Na płytkę FPGA zmień na: 750_000_000 (10 sekund przy zegarze 75MHz)

)
(
	input wire        CLK,
	input wire        RST,
	input wire [10:0] H_CNT,
	input wire [10:0] V_CNT,
	input wire        EncA_QA, EncA_QB, EncB_QA, EncB_QB,
	output reg [7:0]  RED, GREEN, BLUE,
	output wire [3:0] LED
);

  //-----------------------------------------
  // LFSR I ZEGAR GRY
  //-----------------------------------------
  reg [15:0] lfsr;
  wire lfsr_feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

  always @(posedge CLK or posedge RST) begin
    if (RST) lfsr <= 16'hACE1;
    else     lfsr <= {lfsr[14:0], lfsr_feedback};
  end

  reg [31:0] heartbeat;
  always@(posedge CLK or posedge RST)
    if(RST) heartbeat <= 0;
    else    heartbeat <= heartbeat + 1;
    
  assign LED = heartbeat[26:23];

  //-----------------------------------------
  // ZEGARY I PRĘDKOŚĆ
  //-----------------------------------------
  reg [3:0] level;
  reg [31:0] current_speed;
  always @(*) begin
    case(level)
      4'd0: current_speed = 32'd2500;
      4'd1: current_speed = 32'd1667; 
      4'd2: current_speed = 32'd1111; 
      4'd3: current_speed = 32'd741;  
      4'd4: current_speed = 32'd494;  
      4'd5: current_speed = 32'd329;  
      4'd6: current_speed = 32'd219;  
      4'd7: current_speed = 32'd146;  
      4'd8: current_speed = 32'd98;   
      4'd9: current_speed = 32'd65;   
      default: current_speed = 32'd2500;
    endcase
  end
  
  reg [31:0] tick_counter;
  wire game_tick = (tick_counter >= current_speed);

  always @(posedge CLK or posedge RST) begin
    if (RST) tick_counter <= 0;
    else if (game_tick) tick_counter <= 0;
    else tick_counter <= tick_counter + 1;
  end

  reg [31:0] bullet_tick_counter;
  wire bullet_tick = (bullet_tick_counter >= BULLET_SPEED);

  always @(posedge CLK or posedge RST) begin
    if (RST) bullet_tick_counter <= 0;
    else if (bullet_tick) bullet_tick_counter <= 0;
    else bullet_tick_counter <= bullet_tick_counter + 1;
  end

  //-----------------------------------------
  // OBSŁUGA ENKODERA
  //-----------------------------------------
  reg EncA_QA_d, EncA_QA_dd, EncA_QB_d;
  always @(posedge CLK) begin
    EncA_QA_d  <= EncA_QA;
    EncA_QA_dd <= EncA_QA_d; 
    EncA_QB_d  <= EncA_QB;
  end

  wire enc_tick = (EncA_QA_dd == 1'b1 && EncA_QA_d == 1'b0); 
  wire move_right = enc_tick && (EncA_QB_d == 1'b0);
  wire move_left  = enc_tick && (EncA_QB_d == 1'b1);

  //-----------------------------------------
  // AUTOMATYCZNE STRZELANIE
  //-----------------------------------------
  reg [27:0] shoot_timer;
  always @(posedge CLK or posedge RST) begin
    if (RST) shoot_timer <= 0;
    else if (shoot_timer >= SHOOT_RATE) shoot_timer <= 0;
    else shoot_timer <= shoot_timer + 1;
  end
  
  wire auto_shoot_tick = (shoot_timer == 0);

  //-----------------------------------------
  // GŁÓWNA LOGIKA GRY (MENU, DEMO, GAME)
  //-----------------------------------------
  reg in_menu;
  reg in_demo; 
  reg game_over; 
  reg [31:0] demo_timer; 

  reg [10:0] player_x, player_y;
  reg [10:0] bullet_x, bullet_y; 
  reg bullet_active;             
  
  reg [10:0] fleet_x, fleet_y;
  reg fleet_dir;             
  reg [3:0] alien_alive;     
  reg [3:0] alien_tick_div;
  
  reg [3:0] score_thousands, score_hundreds, score_tens, score_ones;
  
  integer j;

  always @(posedge CLK or posedge RST) begin
    if(RST) begin
      in_menu <= 1;
      in_demo <= 0;
      game_over <= 0;
      demo_timer <= 0;
    end
    else if (in_menu) begin
      if (move_right) begin
        in_menu <= 0;
        in_demo <= 0;
        demo_timer <= 0;
        
        player_x <= SCR_W/2 - (PLAYER_W/2);
        player_y <= SCR_H - PLAYER_H - 2; 
        bullet_active <= 0; bullet_x <= 0; bullet_y <= 0;
        fleet_x <= 10; fleet_y <= 6; fleet_dir <= 0;
        alien_alive <= 4'b1111; 
        alien_tick_div <= 0;
        score_thousands <= 0; score_hundreds <= 0;
        score_tens <= 0; score_ones <= 0;
        level <= 0; game_over <= 0;
      end
      else if (demo_timer >= MENU_WAIT_TIME) begin
        in_menu <= 0;
        in_demo <= 1;
        demo_timer <= 0;

        player_x <= SCR_W/2 - (PLAYER_W/2);
        player_y <= SCR_H - PLAYER_H - 2; 
        bullet_active <= 0; bullet_x <= 0; bullet_y <= 0;
        fleet_x <= 10; fleet_y <= 6; fleet_dir <= 0;
        alien_alive <= 4'b1111; 
        alien_tick_div <= 0;
        score_thousands <= 0; score_hundreds <= 0;
        score_tens <= 0; score_ones <= 0;
        level <= 0; game_over <= 0;
      end
      else begin
        demo_timer <= demo_timer + 1;
      end
    end
    else if (game_over && !in_demo) begin
      if (move_right || move_left) begin
        in_menu <= 1;
        game_over <= 0;
        demo_timer <= 0;
      end
    end
    else if (in_demo && (move_right || move_left)) begin
      in_menu <= 1;
      in_demo <= 0;
      game_over <= 0;
      demo_timer <= 0;
    end
    else if (in_demo && (demo_timer >= DEMO_LOOP_TIME || game_over)) begin
      demo_timer <= 0;
      game_over <= 0;
      
      player_x <= SCR_W/2 - (PLAYER_W/2);
      player_y <= SCR_H - PLAYER_H - 2; 
      bullet_active <= 0; bullet_x <= 0; bullet_y <= 0;
      fleet_x <= 10; fleet_y <= 6; fleet_dir <= 0;
      alien_alive <= 4'b1111; 
      alien_tick_div <= 0;
      score_thousands <= 0; score_hundreds <= 0;
      score_tens <= 0; score_ones <= 0;
      level <= 0; 
    end
    else begin
      
      if (in_demo) demo_timer <= demo_timer + 1;

      if (!in_demo) begin
        if (move_right && player_x < SCR_W - PLAYER_W) player_x <= player_x + 1;
        else if (move_left && player_x > 0)            player_x <= player_x - 1;
      end 
      else begin
        // AI dla Demo
        if (game_tick) begin
           if (player_x + 2 < fleet_x + 12 && player_x < SCR_W - PLAYER_W) player_x <= player_x + 1;
           else if (player_x + 2 > fleet_x + 12 && player_x > 0) player_x <= player_x - 1;
        end
      end

      if (auto_shoot_tick && !bullet_active) begin
        bullet_active <= 1;
        bullet_x <= player_x + (PLAYER_W / 2); 
        bullet_y <= player_y - 1;
      end

      if (bullet_active) begin
        for (j = 0; j < 4; j = j + 1) begin
          if (alien_alive[j] && 
              bullet_x >= fleet_x + (j * 8) && bullet_x < fleet_x + (j * 8) + ALIEN_W &&
              bullet_y >= fleet_y && bullet_y < fleet_y + ALIEN_H) begin
     
                alien_alive[j] <= 0;
                bullet_active <= 0;  
                
                if (score_ones == 9) begin
                  score_ones <= 0;
                  if (score_tens == 9) begin
                    score_tens <= 0;
                    if (score_hundreds == 9) begin
                      score_hundreds <= 0;
                      if (score_thousands != 9) score_thousands <= score_thousands + 1;
                    end else score_hundreds <= score_hundreds + 1;
                  end else score_tens <= score_tens + 1;
                end else score_ones <= score_ones + 1;
          end
        end
      end

      if (alien_alive == 4'b0000) begin
        alien_alive <= 4'b1111;
        fleet_x <= 10;
        fleet_y <= 6;            
        fleet_dir <= 0;
        if (level < 9) level <= level + 1;
      end

      if (fleet_y + ALIEN_H >= player_y) begin
        game_over <= 1;
      end

      if (bullet_tick) begin
        if (bullet_active) begin
          if (bullet_y > 0) bullet_y <= bullet_y - 1;
          else bullet_active <= 0; 
        end
      end

      if(game_tick) begin
        alien_tick_div <= alien_tick_div + 1;
        if (alien_tick_div == 0) begin
          if (fleet_dir == 0) begin
            if (fleet_x + 29 < SCR_W) fleet_x <= fleet_x + 2;
            else begin
              fleet_dir <= 1;
              fleet_y <= fleet_y + 2;   
            end
          end else begin
            if (fleet_x >= 2) fleet_x <= fleet_x - 2;
            else begin
              fleet_dir <= 0;
              fleet_y <= fleet_y + 2;   
            end
          end
        end
      end
    end
  end

  //-----------------------------------------
  // RENDEROWANIE TEKSTU I GWIAZD
  //-----------------------------------------
  wire is_score_thou  = (!in_menu) && (H_CNT >= 48 && H_CNT <= 50 && V_CNT >= 1 && V_CNT <= 5);
  wire is_score_hund  = (!in_menu) && (H_CNT >= 52 && H_CNT <= 54 && V_CNT >= 1 && V_CNT <= 5);
  wire is_score_tens  = (!in_menu) && (H_CNT >= 56 && H_CNT <= 58 && V_CNT >= 1 && V_CNT <= 5);
  wire is_score_ones  = (!in_menu) && (H_CNT >= 60 && H_CNT <= 62 && V_CNT >= 1 && V_CNT <= 5);
  wire is_char_L      = (!in_menu) && (H_CNT >= 2  && H_CNT <= 4  && V_CNT >= 1 && V_CNT <= 5);
  wire is_level_digit = (!in_menu) && (H_CNT >= 6  && H_CNT <= 8  && V_CNT >= 1 && V_CNT <= 5);
  
  wire is_menu_J  = in_menu && (H_CNT >= 24 && H_CNT <= 29 && V_CNT >= 8 && V_CNT <= 17);
  wire is_menu_D  = in_menu && (H_CNT >= 34 && H_CNT <= 39 && V_CNT >= 8 && V_CNT <= 17);
  
  wire is_menu_S  = in_menu && (H_CNT >= 23 && H_CNT <= 25 && V_CNT >= 25 && V_CNT <= 29);
  wire is_menu_T1 = in_menu && (H_CNT >= 27 && H_CNT <= 29 && V_CNT >= 25 && V_CNT <= 29);
  wire is_menu_A  = in_menu && (H_CNT >= 31 && H_CNT <= 33 && V_CNT >= 25 && V_CNT <= 29);
  wire is_menu_R  = in_menu && (H_CNT >= 35 && H_CNT <= 37 && V_CNT >= 25 && V_CNT <= 29);
  wire is_menu_T2 = in_menu && (H_CNT >= 39 && H_CNT <= 41 && V_CNT >= 25 && V_CNT <= 29);

  // NOWOŚĆ: Napis DEMO (wyświetlany tylko w trybie demo) - Idealnie wyśrodkowany
  wire is_demo_D = in_demo && (H_CNT >= 25 && H_CNT <= 27 && V_CNT >= 18 && V_CNT <= 22);
  wire is_demo_E = in_demo && (H_CNT >= 29 && H_CNT <= 31 && V_CNT >= 18 && V_CNT <= 22);
  wire is_demo_M = in_demo && (H_CNT >= 33 && H_CNT <= 35 && V_CNT >= 18 && V_CNT <= 22);
  wire is_demo_O = in_demo && (H_CNT >= 37 && H_CNT <= 39 && V_CNT >= 18 && V_CNT <= 22);

  wire is_menu_text = is_menu_J | is_menu_D | is_menu_S | is_menu_T1 | is_menu_A | is_menu_R | is_menu_T2;
  wire is_hud_text  = is_score_thou | is_score_hund | is_score_tens | is_score_ones | is_char_L | is_level_digit;
  wire is_demo_text = is_demo_D | is_demo_E | is_demo_M | is_demo_O;
  
  wire is_text_area = in_menu ? is_menu_text : (is_hud_text | is_demo_text);

  reg [4:0] cur_digit;
  reg [2:0] char_x;
  reg [2:0] char_y;

  always @(*) begin
    cur_digit = 0; char_x = 0; char_y = 0;
    if (in_menu) begin
      if (is_menu_J) begin 
        cur_digit = 11; 
        char_x = (H_CNT - 24) >> 1; 
        char_y = (V_CNT - 8) >> 1; 
      end
      else if (is_menu_D) begin 
        cur_digit = 12; 
        char_x = (H_CNT - 34) >> 1; 
        char_y = (V_CNT - 8) >> 1; 
      end
      else begin
        char_y = V_CNT - 25;
        if      (is_menu_S)  begin cur_digit = 5;  char_x = H_CNT - 23; end 
        else if (is_menu_T1) begin cur_digit = 14; char_x = H_CNT - 27; end
        else if (is_menu_A)  begin cur_digit = 15; char_x = H_CNT - 31; end
        else if (is_menu_R)  begin cur_digit = 16; char_x = H_CNT - 35; end
        else if (is_menu_T2) begin cur_digit = 14; char_x = H_CNT - 39; end
      end
    end 
    else begin
      char_y = V_CNT - 1; // Domyślnie HUD
      
      if      (is_score_thou)  begin cur_digit = score_thousands; char_x = H_CNT - 48; end
      else if (is_score_hund)  begin cur_digit = score_hundreds;  char_x = H_CNT - 52; end
      else if (is_score_tens)  begin cur_digit = score_tens;      char_x = H_CNT - 56; end
      else if (is_score_ones)  begin cur_digit = score_ones;      char_x = H_CNT - 60; end
      else if (is_char_L)      begin cur_digit = 10;              char_x = H_CNT - 2;  end
      else if (is_level_digit) begin cur_digit = level;           char_x = H_CNT - 6;  end
      else if (in_demo) begin
        char_y = V_CNT - 18; // Wysokość dla napisu DEMO
        if      (is_demo_D) begin cur_digit = 12; char_x = H_CNT - 25; end
        else if (is_demo_E) begin cur_digit = 17; char_x = H_CNT - 29; end
        else if (is_demo_M) begin cur_digit = 18; char_x = H_CNT - 33; end
        else if (is_demo_O) begin cur_digit = 0;  char_x = H_CNT - 37; end
      end
    end
  end

  reg [14:0] digit_rom;
  always @(*) begin
    case(cur_digit)
      5'd0: digit_rom = 15'b111_101_101_101_111; // 0 (i O)
      5'd1: digit_rom = 15'b010_110_010_010_111;
      5'd2: digit_rom = 15'b111_001_111_100_111;
      5'd3: digit_rom = 15'b111_001_111_001_111;
      5'd4: digit_rom = 15'b101_101_111_001_001;
      5'd5: digit_rom = 15'b111_100_111_001_111; 
      5'd6: digit_rom = 15'b111_100_111_101_111;
      5'd7: digit_rom = 15'b111_001_001_001_001;
      5'd8: digit_rom = 15'b111_101_111_101_111;
      5'd9: digit_rom = 15'b111_101_111_001_111;
      5'd10: digit_rom= 15'b100_100_100_100_111; // L
      5'd11: digit_rom= 15'b001_001_001_101_111; // J
      5'd12: digit_rom= 15'b110_101_101_101_110; // D
      5'd14: digit_rom= 15'b111_010_010_010_010; // T
      5'd15: digit_rom= 15'b010_101_111_101_101; // A
      5'd16: digit_rom= 15'b110_101_110_101_101; // R
      5'd17: digit_rom= 15'b111_100_111_100_111; // E
      5'd18: digit_rom= 15'b101_111_101_101_101; // M
      default: digit_rom = 15'b000_000_000_000_000;
    endcase
  end

  wire [4:0] bit_idx = 14 - (char_y * 3 + char_x); 
  
  reg draw_text_pixel;
  always @(*) begin
    draw_text_pixel = 1'b0;
    if (is_text_area) begin
      if (bit_idx < 15) draw_text_pixel = digit_rom[bit_idx];
    end
  end

  wire blink_hud = (!game_over) || heartbeat[16]; 

  wire is_star = (H_CNT == 3  && V_CNT == 8 ) || (H_CNT == 12 && V_CNT == 4 ) ||
                 (H_CNT == 27 && V_CNT == 2 ) || (H_CNT == 42 && V_CNT == 6 ) ||
                 (H_CNT == 58 && V_CNT == 3 ) || (H_CNT == 8  && V_CNT == 14) ||
                 (H_CNT == 22 && V_CNT == 12) || (H_CNT == 35 && V_CNT == 16) ||
                 (H_CNT == 48 && V_CNT == 11) || (H_CNT == 61 && V_CNT == 15) ||
                 (H_CNT == 5  && V_CNT == 24) || (H_CNT == 18 && V_CNT == 28) ||
                 (H_CNT == 31 && V_CNT == 22) || (H_CNT == 45 && V_CNT == 26) ||
                 (H_CNT == 55 && V_CNT == 20) || (H_CNT == 10 && V_CNT == 36) ||
                 (H_CNT == 25 && V_CNT == 33) || (H_CNT == 38 && V_CNT == 38) ||
                 (H_CNT == 52 && V_CNT == 34) || (H_CNT == 62 && V_CNT == 37);

  //-----------------------------------------
  // GŁÓWNE RENDEROWANIE GRAFIKI
  //-----------------------------------------
  integer i;
  always @(*) begin
    if (is_star) begin
        RED = 8'hFF; GREEN = 8'hFF; BLUE = 8'hFF;
    end else begin
        RED = 8'h00; GREEN = 8'h00; BLUE = 8'h00;
    end

    if (in_menu) begin
      if (H_CNT >= 21 && H_CNT <= 43 && V_CNT >= 23 && V_CNT <= 31) begin
          RED = 8'h60; GREEN = 8'h60; BLUE = 8'h60; 
      end
      
      if (draw_text_pixel) begin
        if (is_menu_J || is_menu_D) begin
          RED = 8'h00; GREEN = 8'hFF; BLUE = 8'hFF; 
        end else begin
          RED = 8'hFF; GREEN = 8'hFF; BLUE = 8'h00;
        end
      end
    end 
    else begin
      // Kosmici
      for (i = 0; i < 4; i = i + 1) begin
        if (alien_alive[i]) begin
          if (H_CNT >= fleet_x + (i * 8) && H_CNT < fleet_x + (i * 8) + ALIEN_W && 
              V_CNT >= fleet_y && V_CNT < fleet_y + ALIEN_H) begin
            RED = 8'h00; GREEN = 8'hFF; BLUE = 8'h00; 
          end
        end
      end

      // Gracz
      if(H_CNT >= player_x && H_CNT < player_x + PLAYER_W && V_CNT >= player_y && V_CNT < player_y + PLAYER_H) begin
        if (game_over) begin
           RED = 8'hFF; GREEN = 8'h00; BLUE = 8'h00; 
        end else begin
           if (H_CNT == player_x + 2 && V_CNT == player_y) begin
             RED = 8'h00; GREEN = 8'hFF; BLUE = 8'hFF; 
           end else begin
             RED = 8'h00; GREEN = 8'h00; BLUE = 8'hFF;
           end
        end
      end

      // Pocisk
      if (bullet_active && H_CNT == bullet_x && V_CNT == bullet_y) begin
          RED = 8'hFF; GREEN = 8'hFF; BLUE = 8'h00;
      end

      // Teksty (HUD oraz DEMO)
      if (draw_text_pixel) begin
        if (in_demo && is_demo_text) begin
          RED = 8'hFF; GREEN = 8'h00; BLUE = 8'hFF; // Magenta/Fiolet dla napisu DEMO
        end 
        else if (is_hud_text && blink_hud) begin
          RED = 8'hFF; GREEN = 8'hFF; BLUE = 8'h00; // Żółty dla HUDu
        end
      end
    end
  end
endmodule