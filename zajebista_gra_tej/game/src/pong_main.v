module pong_main
#(
  parameter SCR_W = 64,
  parameter SCR_H = 40,
  parameter PLAYER_W = 5,
  parameter PLAYER_H = 3,
  parameter ALIEN_W = 3,
  parameter ALIEN_H = 3,
  parameter SHOOT_RATE = 10_000 // Czas między strzałami (Ok. 2 sekundy dla zegara 75MHz)
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

  reg [3:0] level;
  
  // ZEGAR GRY (Prędkość spadania przeciwników / lotu pocisku)
  wire [31:0] current_speed = 2500 - (level * 200); 
  
  reg [31:0] tick_counter;
  wire game_tick = (tick_counter >= current_speed);

  always @(posedge CLK or posedge RST) begin
    if (RST) tick_counter <= 0;
    else if (game_tick) tick_counter <= 0;
    else tick_counter <= tick_counter + 1;
  end

  //-----------------------------------------
  // OBSŁUGA ENKODERA (STEROWANIE GRACZEM)
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
  // AUTOMATYCZNE STRZELANIE (TIMER)
  //-----------------------------------------
  reg [27:0] shoot_timer;
  always @(posedge CLK or posedge RST) begin
    if (RST) shoot_timer <= 0;
    else if (shoot_timer >= SHOOT_RATE) shoot_timer <= 0;
    else shoot_timer <= shoot_timer + 1;
  end
  
  // Impuls wyzwalający strzał dokładnie co wyznaczony czas
  wire auto_shoot_tick = (shoot_timer == 0);

  //-----------------------------------------
  // LOGIKA GRY (STAN GRACZA, POCISK I PUNKTY)
  //-----------------------------------------
  reg [10:0] player_x, player_y;
  reg [10:0] bullet_x, bullet_y; // Pozycja pocisku
  reg bullet_active;             // Czy pocisk jest na ekranie?
  
  reg [3:0] score_thousands, score_hundreds, score_tens, score_ones;
  reg game_over; 

  always @(posedge CLK or posedge RST) begin
    if(RST) begin
      player_x <= SCR_W/2 - (PLAYER_W/2);
      player_y <= SCR_H - PLAYER_H - 2; 
      
      bullet_active <= 0;
      bullet_x <= 0;
      bullet_y <= 0;

      score_thousands <= 0; score_hundreds <= 0;
      score_tens <= 0; score_ones <= 0;
      level <= 0;
      game_over <= 0;
    end
    else if (game_over) begin
      if (move_right || move_left) begin
        player_x <= SCR_W/2 - (PLAYER_W/2);
        bullet_active <= 0;
        score_thousands <= 0; score_hundreds <= 0;
        score_tens <= 0; score_ones <= 0;
        level <= 0;
        game_over <= 0;
      end
    end
    else begin
      // Poruszanie się statkiem
      if (move_right && player_x < SCR_W - PLAYER_W) player_x <= player_x + 1;
      else if (move_left && player_x > 0)            player_x <= player_x - 1;

      // Generowanie strzału (Teraz w pełni automatyczne!)
      if (auto_shoot_tick && !bullet_active) begin
        bullet_active <= 1;
        bullet_x <= player_x + (PLAYER_W / 2); // Strzał ze środka statku
        bullet_y <= player_y - 1;              // Start tuż nad statkiem
      end

      // Ruch elementów zależny od zegara gry
      if(game_tick) begin
        // Ruch pocisku (Leci z dołu do góry, czyli wartość Y maleje)
        if (bullet_active) begin
          if (bullet_y > 0) bullet_y <= bullet_y - 1; 
          else bullet_active <= 0; // Usuń pocisk, jeśli wyleciał za ekran
        end
      end
    end
  end

  //-----------------------------------------
  // RENDEROWANIE TEKSTU (UI)
  //-----------------------------------------
  wire is_score_thou  = (H_CNT >= 48 && H_CNT <= 50 && V_CNT >= 1 && V_CNT <= 5);
  wire is_score_hund  = (H_CNT >= 52 && H_CNT <= 54 && V_CNT >= 1 && V_CNT <= 5);
  wire is_score_tens  = (H_CNT >= 56 && H_CNT <= 58 && V_CNT >= 1 && V_CNT <= 5);
  wire is_score_ones  = (H_CNT >= 60 && H_CNT <= 62 && V_CNT >= 1 && V_CNT <= 5);
  wire is_char_L      = (H_CNT >= 2  && H_CNT <= 4  && V_CNT >= 1 && V_CNT <= 5);
  wire is_level_digit = (H_CNT >= 6  && H_CNT <= 8  && V_CNT >= 1 && V_CNT <= 5);
  wire is_text_area = is_score_thou | is_score_hund | is_score_tens | is_score_ones | is_char_L | is_level_digit;

  wire [3:0] cur_digit = is_score_thou  ? score_thousands :
                         is_score_hund  ? score_hundreds  :
                         is_score_tens  ? score_tens      :
                         is_score_ones  ? score_ones      :
                         is_char_L      ? 4'd10           : 
                         is_level_digit ? level           : 4'd0;

  reg [14:0] digit_rom;
  always @(*) begin
    case(cur_digit)
      4'd0: digit_rom = 15'b111_101_101_101_111;
      4'd1: digit_rom = 15'b010_110_010_010_111;
      4'd2: digit_rom = 15'b111_001_111_100_111;
      4'd3: digit_rom = 15'b111_001_111_001_111;
      4'd4: digit_rom = 15'b101_101_111_001_001;
      4'd5: digit_rom = 15'b111_100_111_001_111;
      4'd6: digit_rom = 15'b111_100_111_101_111;
      4'd7: digit_rom = 15'b111_001_001_001_001;
      4'd8: digit_rom = 15'b111_101_111_101_111;
      4'd9: digit_rom = 15'b111_101_111_001_111;
      4'd10: digit_rom= 15'b100_100_100_100_111; // Litera 'L'
      default: digit_rom = 15'b000_000_000_000_000;
    endcase
  end

  wire [2:0] char_x = is_score_thou  ? (H_CNT - 48) :
                      is_score_hund  ? (H_CNT - 52) :
                      is_score_tens  ? (H_CNT - 56) :
                      is_score_ones  ? (H_CNT - 60) :
                      is_char_L      ? (H_CNT - 2)  :
                      is_level_digit ? (H_CNT - 6)  : 3'd0;

  wire [2:0] char_y = V_CNT - 1;
  wire [4:0] bit_idx = 14 - (char_y * 3 + char_x); 
  
  reg draw_text_pixel;
  always @(*) begin
    draw_text_pixel = 1'b0;
    if (is_text_area) begin
      if (bit_idx < 15) draw_text_pixel = digit_rom[bit_idx];
    end
  end

  wire blink_state = heartbeat[16]; 
  wire show_score = (!game_over) || blink_state;

  //-----------------------------------------
  // GŁÓWNE RENDEROWANIE GRAFIKI
  //-----------------------------------------
  always @(*) begin
    // Domyślne tło: Czarny kosmos
    RED = 8'h00; GREEN = 8'h00; BLUE = 8'h00;

    // Rysowanie gracza (Statek)
    if(H_CNT >= player_x && H_CNT < player_x + PLAYER_W && V_CNT >= player_y && V_CNT < player_y + PLAYER_H) begin
      if (H_CNT == player_x + 2 && V_CNT == player_y) begin
        RED = 8'h00; GREEN = 8'hFF; BLUE = 8'hFF; 
      end else begin
        RED = 8'h00; GREEN = 8'h00; BLUE = 8'hFF;
      end
    end

    // Rysowanie pocisku (Biały laser)
    if (bullet_active && H_CNT == bullet_x && V_CNT == bullet_y) begin
        RED = 8'hFF; GREEN = 8'hFF; BLUE = 8'hFF;
    end

    // Rysowanie UI (Punkty i Level) na żółto
    if (draw_text_pixel && show_score) begin
        RED = 8'hFF; GREEN = 8'hFF; BLUE = 8'h00;
    end
  end
endmodule