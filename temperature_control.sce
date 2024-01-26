//-------------------------------------Inicjalizacja Portu-------------------------------------//                           
ID_port=evstr(x_dialog('Wybierz numer portu COM: ','7'))//wybór numeru portu COM
if ID_port==[] then                       
        msg=_("ERROR: Nie został wybrany żaden port. ");
        messagebox(msg, "ERROR", "error");      
        error(msg);                             
        return;                                
end
global %serial_port //zmienna odpowiadająca za komunikację szeregową                                         
%serial_port=openserial(ID_port,"9600,n,8,1");//(prędkość 9600, bez parzystości, 8 bitów danych, 1 bit stopu)  

//-------------------------------------Monitorowanie-------------------------------------//
global %MaxTemp                     //maksymalna temperatura
%MaxTemp = 35;                     
f=figure("dockable","off");         
f.resize="off";                     
f.menubar_visible="off";            
f.toolbar_visible="off";            
f.figure_name="Monitorowanie i kontrola sensora temperatury";   
f.tag="okno";                 
bar(.5,0);                   
e = gce();                          //uzyskanie dostępu do bieżącego obiektu graficznego
e = e.children(1);                  // uzyskanie dostępu do ostatniego używaneg obiektu
e.tag = "aktualnyOdczyt";            

plot([0, 3], [%MaxTemp, %MaxTemp]); 
e = gce();                          
e = e.children(1);                  
e.tag = "aktualnaMaxTemperatura";           
e.line_style = 5;                   
e.thickness = 2;                    
e.foreground = color("red");        
a = gca();                          // Pobranie aktualnych osi
a.data_bounds = [0, 0; 1, 45];      // zakres osi
a.grid = [-1, color("darkgrey")];   
a.axes_bounds = [0.05, 0.2, 0.25, 0.85]; 
a.axes_visible(1) = "off";          
//a.tag = "liveAxes";                 
a.title.text="Aktualna temperatura";
f.figure_size = [1000 700];         
f.background = color(246,244,242)   

//-------------------------------------Suwak-------------------------------------//
suwakMaxTemperatura = uicontrol("style", "slider", "position", [20 30 30 440], ...
"min", 0, "max", 45, "sliderstep", [1 5], "value" , %MaxTemp, ...           
"callback", "zmienMaxTemperature", "tag", "suwakMaxTemperatura");                       

//-------------------------------------Funkcje-------------------------------------//
function zmienMaxTemperature()
    global %MaxTemp                      
    e = findobj("tag", "suwakMaxTemperatura"); 
    %MaxTemp = e.value                   
    e = findobj("tag", "aktualnaMaxTemperatura");
    e.data(:,2) = %MaxTemp;              
endfunction
//
function zamknijOkno()
    stopCzujnik();                    
    global %serial_port              
        closeserial(%serial_port);   

    f = findobj("tag", "okno");
    delete(f);                       
endfunction
//
function stopCzujnik()
    global %odczytywanieDanych             
    %odczytywanieDanych = %f;              // Zatrzymanie odczytów z czujnika
endfunction
//
function startCzujnik()
    global %MaxTemp                 
    global %serial_port             
    global %odczytywanieDanych            
    %odczytywanieDanych = %t;              // Inicjalizacja zmiennej odczytywanieDanych na wartość true
    global %stanWentylatora               
    %stanWentylatora = 0;                 
    // Arduino toolbox
    wartosci=[];                      
    wartosc=null;                 
    while %odczytywanieDanych             
       while(wartosc~=ascii(13)) then 
               
        wartosc=readserial(%serial_port,1);
        wartosci=wartosci+wartosc;        
        v=strsubst(wartosci,string(ascii(10)),'')// Usunięcie znaku nowej linii (ASCII 10) ze zmiennej wartosci
        v=strsubst(v,string(ascii(13)),'')// Usunięcie znaku powrotu karetki (ASCII 13) ze zmiennej v
        aktualnaTemperatura=evstr(v)               // Przekonwertowanie v na wartość typu string
        end
    //xinfo
    xinfo("Temperatura = "+v+"°C");
    wartosci=[]                      
    wartosc=null;                
    aktualizujTemperature(aktualnaTemperatura);

//-------------------------------------Sterowanie wentylatorem-------------------------------------//
    global %RstanRegulacji      
    if  %RstanRegulacji == 1 then
        if aktualnaTemperatura > %MaxTemp then    
            startWentylator();           
        else
            stopWentylator();          
        end
    end
    zaktualizujStanWentylatora(%stanWentylatora);    
end
endfunction
//
function aktualizujTemperature(aktualnaTemperatura)
    global %MaxTemp                 
    
    e = findobj("tag", "aktualnyOdczyt");
    e.data(2) = aktualnaTemperatura;               
    if aktualnaTemperatura > %MaxTemp then         
        e.background = color("red");
    else
        e.background = color("green");
    end
    e = findobj("tag", "wykresTemperatury");
    ostatnieOdczyty = e.data(:, 2);      // Pobranie ostatnich wartości z drugiej kolumny danych obiektu
    e.data(:, 2) = [ostatnieOdczyty(2:$) ; aktualnaTemperatura];// Aktualizacja danych obiektu, dodanie nowej wartości temperatury na koniec danych
endfunction

//-------------------------------------Regulacja-------------------------------------//
global %RstanRegulacji
%RstanRegulacji = 1;
// tutaj wymiary
pozycjaWykresu = [0.25 0 0.8 1];//Wartości [0.1, 0.2, 0.25, 0.85] określają granice osi jako [lewa, dolna, szerokość, wysokość] w jednostkach względnych (w zakresie od 0 do 1).
minZakresTemperatura = 15;
maxZakresTemperatura = 35;
minZakresWentylator = -0.2;
maxZakresWentylator = 1.2;

//-------------------------------------Wykres Zmian Temperatury-------------------------------------//
okres = 60; 
subplot(222);
a = gca();
a.axes_bounds = pozycjaWykresu;
//a.tag = "minuteAxes";
plot2d(0:okres, zeros(1,okres + 1), color("red"));
a.title.text="Zmiany temperatury w ciągu ostatnich 60sekund";
a.data_bounds = [0, minZakresTemperatura; okres, maxZakresTemperatura];
e = gce();
e = e.children(1);
e.tag = "wykresTemperatury";
// Dodanie drugiej osi pionowej do pokazania ON/OFF wentylatora
a = newaxes();
a.y_location = "right";
a.filled = "off" 
a.axes_bounds = pozycjaWykresu;
plot2d(0:okres, zeros(1,okres + 1), color("blue"));
a.data_bounds = [0, minZakresWentylator; okres, maxZakresWentylator];
a.axes_visible(1) = "off";
a.foreground=color("blue");
a.font_color=color("blue");
e = gce();
e = e.children(1);
e.tag = "wykresWentylatora";

//-------------------------------------Funkcje-------------------------------------// 
function resetWykresu()
    e = findobj("tag", "aktualnyOdczyt");
    e.data(:, 2) = 0;
    e = findobj("tag", "wykresTemperatury");
    e.data(:, 2) = 0;
    e = findobj("tag", "wykresWentylatora");
    e.data(:, 2) = 0;
endfunction
//
function zmianaStanuRegulacji()
    global %RstanRegulacji
    e = findobj("tag", "zmiennaRegulacji");
    %RstanRegulacji = e.value;
    if %RstanRegulacji == 0 then
        stopWentylator();
    end
endfunction
//
function zaktualizujStanWentylatora(aktualnaTemperatura)
    e = findobj("tag", "wykresWentylatora");
    ostatnieOdczyty = e.data(:, 2);
    e.data(:, 2) = [ostatnieOdczyty(2:$) ; aktualnaTemperatura];    
endfunction
//
function startWentylator()
    global %serial_port
        writeserial(%serial_port,"H");
    global %stanWentylatora
    %stanWentylatora = 1;
endfunction
//
function stopWentylator()
    global %serial_port
        writeserial(%serial_port,"L");
    global %stanWentylatora
    %stanWentylatora = 0;
endfunction

//-------------------------------------Przyciski-------------------------------------//
panelSterowania = uicontrol(f, "style", "frame", "position", [15 560 305 80], ...
"tag", "panelSterowania", "ForegroundColor", [0/255 0/255 0/255],...
"border", createBorder("titled", createBorder("line", "lightGray", 1)...
, _("Panel sterowania"), "center", "top", createBorderFont("", 11, "normal"), ...
"black"));
//
przyciskStartu = uicontrol(f, "style", "pushbutton", "position", ...
[20 595 145 30], "callback", "startCzujnik", "string", "Start Symulacji", ...
"tag", "przyciskStartu");
//
przyciskStopu = uicontrol(f, "style", "pushbutton", "position", ...
[170 595 145 30], "callback", "stopCzujnik", "string", "Stop Symulacji", ...
"tag", "przyciskStopu");
//
przyciskResetu = uicontrol(f, "style", "pushbutton", "position", ...
[20 565 145 30], "callback", "resetWykresu", "string", "Reset", ...
"tag", "przyciskResetu");
//
przyciskZamkniecia = uicontrol(f, "style", "pushbutton", "position", ...
[170 565 145 30], "callback", "zamknijOkno", "string", "Zamknij", ...
"tag", "przyciskZamkniecia");

//-------------------------------------Tryb Regulacji-------------------------------------//
panelRegulacji = uicontrol(f, "style", "frame", "position", [15 510 305 50]...
,"tag", "panelSterowania", "ForegroundColor", [0/255 0/255 0/255],...
"border", createBorder("titled", createBorder("line", "lightGray", 1), ...
_("Regulacja"), "center", "top", createBorderFont("", 11, "normal"),...
 "black"));
//
enableRegulation = uicontrol(f, "style", "checkbox", "position", ...
[135 520 140 20],"string", "ON/OFF", "value", %RstanRegulacji, ...
"callback", "zmianaStanuRegulacji", "tag", "zmiennaRegulacji");
