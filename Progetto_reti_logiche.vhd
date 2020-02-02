--  PROGETTO RETI LOGICHE 2018/19

library IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;

entity project_reti_logiche is
    Port (
           i_clk : in std_logic;
           i_start : in std_logic;
           i_rst : in std_logic; 
           i_data : in std_logic_vector(7 downto 0);
           o_address : out std_logic_vector(15 downto 0);
           o_done : out std_logic;
           o_en : out std_logic;
           o_we : out std_logic;
           o_data : out std_logic_vector(7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
																			--Viene creato un tipo per rappresentare i possibili stati del componente
    type tipo_stato is ( INIZIO, INIZIO_LETTURA, CLOCK, SALVA, AUMENTA_INDIRIZZO,CALCOLA_DISTANZA, SALVA_DISTANZA,
						 CALCOLA_DISTANZA_MINIMA, SCRITTURA_MASCHERA_OUT, DONE_ALTO, DONE_BASSO, STATO_SCRITTURA );
    signal stato : tipo_stato;
	type matrix_distanze is array (7 downto 0) of unsigned(8 downto 0);		--Dichiarazione del tipo di dato che usiamo per salvare tutte le distanze che calcoliamo
	
begin
    process(i_clk, i_rst)     												--il processo è eseguito ad commutazione del clock, la sincronizzazione sul fronte di salita Ã¨ eseguita successivamente 
																			--i_rst è stato inserito nella sensitivity list per permettere reset asincroni						  
	variable indirizzo_corrente : std_logic_vector(15 downto 0);			--Dichiarazione variabili
	variable distanza_minima : unsigned(8 downto 0);
	variable maschera_in, maschera_out : std_logic_vector(7 downto 0);
	variable x_riferimento, y_riferimento, x_centroide, y_centroide, distanza : unsigned(8 downto 0);
	variable i : integer range 0 to 8 := 0;
	variable passo : integer range 0 to 5 := 0;
	
	variable tutte_distanze : matrix_distanze;								--Dichiarazione della matrice delle distanze

	begin
        if (i_rst = '1') then 												--Controllo segnale di reset
            stato <= INIZIO;
        end if;
        if (i_clk 'event and i_clk = '1') then 								--Sincronizzazione sul fronte di salita del clock
            case stato is
                when INIZIO => 
                    if (i_start = '1') then 								--Attendi il segnale di start
                        indirizzo_corrente := "0000000000000000";
						i := 0;
						passo := 0;
						distanza_minima := "111111111";
                        stato <= INIZIO_LETTURA;
                    end if;
				
				when INIZIO_LETTURA => 											--Settaggio dei segnali per la lettura
					o_en <= '1';
					o_we <= '0';
					o_address <= indirizzo_corrente;
					stato <= CLOCK;
				
				when CLOCK =>													--Ciclo di Clock
					passo := passo + 1;
					stato <= SALVA;	
				
				when SALVA =>
					if (passo = 1) then											--Salva maschera di input (indirizzo 0)
						maschera_in := i_data;
						indirizzo_corrente := "0000000000010001";				--Settiamo l'indirizzo della coordinata x del centroide di riferimento (indirizzo 17)
						stato <= INIZIO_LETTURA;
					elsif (passo = 2) then										--Salva x del centroide di riferimento
							x_riferimento := unsigned('0' & i_data);			--Aggiunta di un bit per poter lavorare con 9 bit (distanza massima: 510)
							indirizzo_corrente := indirizzo_corrente + "0000000000000001";
							stato <= INIZIO_LETTURA;
						elsif (passo = 3) then									--Salva y del centroide di riferimento						
								y_riferimento := unsigned('0' & i_data);		
								indirizzo_corrente := "0000000000000000";
								stato <= AUMENTA_INDIRIZZO;
							elsif (passo = 4) then								--Salva x del centroide per poter calcolare la distanza 
									x_centroide := unsigned('0' & i_data);
									indirizzo_corrente := indirizzo_corrente + "0000000000000001";
									stato <= INIZIO_LETTURA;
								elsif (passo = 5) then							--Salva y del centroide per poter calcolare la distanza 
										y_centroide := unsigned('0' & i_data);
										passo := 3;
										stato <= CALCOLA_DISTANZA;
										
					end if;
				
				when AUMENTA_INDIRIZZO =>
					if(i < 8) then
						if(maschera_in(i) = '1') then
							indirizzo_corrente := indirizzo_corrente + "0000000000000001";
							stato <= INIZIO_LETTURA;
						else
							indirizzo_corrente := indirizzo_corrente + "0000000000000010";
							i := i + 1;
							stato <= AUMENTA_INDIRIZZO;
						end if; 											
					else
						i := 0;
						indirizzo_corrente := indirizzo_corrente + "0000000000000011";			--Reset della variabile di conteggio
						stato <= STATO_SCRITTURA ;
					end if;
					
                when STATO_SCRITTURA =>
                    o_address <= indirizzo_corrente;
                    stato <= SCRITTURA_MASCHERA_OUT;
				
				when CALCOLA_DISTANZA =>									--Metodo alternativo nel calcolo della distanza al posto di fare il modulo
					if(x_centroide>x_riferimento) then
						if(y_centroide>y_riferimento) then
							distanza := (x_centroide-x_riferimento)+(y_centroide-y_riferimento);
						else
							distanza := (x_centroide-x_riferimento)+(y_riferimento-y_centroide);
						end if;
					else
						if(y_centroide>y_riferimento) then
							distanza := (x_riferimento-x_centroide)+(y_centroide-y_riferimento);
						else
							distanza := (x_riferimento-x_centroide)+(y_riferimento-y_centroide);
						end if;
					end if;
					stato <= SALVA_DISTANZA;
					
				when SALVA_DISTANZA =>
					tutte_distanze(i) := distanza;
					stato <= CALCOLA_DISTANZA_MINIMA;
				
				when CALCOLA_DISTANZA_MINIMA =>
					if (distanza < distanza_minima) then
						distanza_minima := distanza;
					end if;
					i := i + 1;
					stato <= AUMENTA_INDIRIZZO;
				
				when SCRITTURA_MASCHERA_OUT =>						--Stato per scrivere la maschera di uscita ciclando per 8 volte su se stesso
					if(i < 8) then
						if(maschera_in(i) = '1') then
							if(tutte_distanze(i) = distanza_minima) then
								maschera_out(i) := '1';
							else
								maschera_out(i) := '0';
							end if;
						else
							maschera_out(i) := '0';
						end if;
						i := i + 1;
						stato <= SCRITTURA_MASCHERA_OUT;
					else
						o_en <= '1';
						o_we <= '1';
						o_data <= maschera_out;
						stato <= DONE_ALTO;
					end if;
						
			    when DONE_ALTO =>
					o_done <= '1';
					if (i_start = '0') then
				       stato <= DONE_BASSO;
					else 
					   stato <= DONE_ALTO;									
					end if;
				
				when DONE_BASSO =>
				    o_done <= '0';
				    if (i_start = '1') then
				       stato <= INIZIO;
				    else
				       stato <= DONE_BASSO;
				    end if;
				    
			end case;
		end if;
	end process;
end Behavioral;
					