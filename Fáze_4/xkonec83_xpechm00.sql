-- SQL Skript na vytvoření základní struktury databáze, na její naplnění fiktivními daty, na vytvoření dotazů nad samotnou databází
-- a na vytvoření pokročilých databázových objektů.
-- Autor: Martin Pech (xpechm00)
-- Autor: David Konečný (xkonec83)

SET SERVEROUTPUT ON;

------------DROP------------
DROP TABLE Zamestnanec;
DROP TABLE KvalifikaceInstruktora;
DROP TABLE Kvalifikace;
DROP TABLE Individual;
DROP TABLE MistnostSkupina;
DROP TABLE Mistnost;
DROP TABLE Skupinove;
DROP TABLE Rezervace;
DROP TABLE Lekce;
DROP TABLE Instruktor;
DROP TABLE Klient;
DROP TABLE Recepcni;
DROP TABLE Klientska_karta;

DROP MATERIALIZED VIEW ZamestanecKvalifikaci;


------------CREATE------------
--TABULKA RECEPCNI - GENERALIZACE Z TABULKY ZAMESTNANCE
CREATE TABLE Recepcni (
ID_rec INT GENERATED AS IDENTITY PRIMARY KEY,
Pracovni_pomer VARCHAR(20)
);

--TABULKA INSTRUKTOR - GENERALIZACE Z TABULKY ZAMESTNANCE
CREATE TABLE Instruktor(
ID_instruktora INT GENERATED AS IDENTITY PRIMARY KEY
);

-- TABULKA ZAMESTNANEC
CREATE TABLE Zamestnanec (
ID_zamestnance INT GENERATED AS IDENTITY PRIMARY KEY,
Rodne_cislo CHAR(11)
    CHECK(REGEXP_LIKE(Rodne_cislo, '^[0-9]{6,6}\/[0-9]{3,4}$')),
Jmeno VARCHAR(20) NOT NULL,
Prijmeni VARCHAR(20) NOT NULL,
Telefon VARCHAR(12) NOT NULL,
Email VARCHAR(40)
    CHECK(REGEXP_LIKE(Email, '^[a-z]+[a-z0-9\.]*@[a-z0-9\.-]+\.[a-z]{2,}$', 'i')),
Recepcni_ID INT DEFAULT NULL,
id_instruktora INT DEFAULT NULL,
CONSTRAINT zamestnanec_recepcni_FK FOREIGN KEY (Recepcni_ID) REFERENCES Recepcni (ID_rec) ON DELETE SET NULL,
CONSTRAINT zamestnanec_instruktor_FK FOREIGN KEY (id_instruktora) REFERENCES Instruktor (ID_instruktora) ON DELETE SET NULL
);

--TABULKA KVALIFIKACE
CREATE TABLE Kvalifikace(
ID_kvalifikace INT GENERATED AS IDENTITY PRIMARY KEY,
Nazev VARCHAR (40) NOT NULL,
Popis VARCHAR (100)
);

--TABULKA KVALIFIKACE INSTRUKTORA
CREATE TABLE KvalifikaceInstruktora(
ID_instruktora INT NOT NULL,
ID_kvalifikace INT NOT NULL,
CONSTRAINT instruktor_kvalifikace_PK 
    PRIMARY KEY (ID_instruktora, ID_kvalifikace),
CONSTRAINT instruktor_KI_FK
    FOREIGN KEY (ID_instruktora) REFERENCES Instruktor(ID_instruktora),
CONSTRAINT kvalifikace_KI_FK
    FOREIGN KEY (ID_kvalifikace) REFERENCES Kvalifikace(ID_kvalifikace)
);

--TABULKA LEKCE
CREATE TABLE Lekce(
ID_Lekce INT GENERATED AS IDENTITY PRIMARY KEY, --formát + ID_Mistnosti(2) +  4 unikátní čísla
Datum TIMESTAMP NOT NULL,
ID_instruktora INT,
CONSTRAINT ID_gen UNIQUE(ID_Lekce, Datum),
CONSTRAINT Instruktor_Lekce 
    FOREIGN KEY(ID_instruktora) REFERENCES Instruktor(ID_instruktora)
);

--TABULKA INDIVIDUAL - GENERALIZACE Z TABULKY LEKCE
CREATE TABLE Individual (
ID_ind INT PRIMARY KEY,
CONSTRAINT individual_lekce_FK
    FOREIGN KEY (ID_ind) REFERENCES Lekce (ID_Lekce)
);

-- TABULKA SKUPINOVÝCH LEKCÍ - GENERALIZACE Z TABULKY LEKCE
CREATE TABLE Skupinove (
ID_skup INT PRIMARY KEY,
Nazev VARCHAR(40) NOT NULL,
Kapacita INT,
CONSTRAINT Skup_Lekce_FK
    FOREIGN KEY (ID_skup) REFERENCES Lekce (ID_Lekce)
);

--TABULKA MISTNOST
CREATE TABLE Mistnost(
ID_Mistnosti INT GENERATED AS IDENTITY PRIMARY KEY,
Oznaceni VARCHAR(20),
Umisteni VARCHAR(20),
Kapacita INT NOT NULL
);

--TABULKA MISTNOSTSKUPINA
CREATE TABLE MistnostSkupina(
ID_Lek INT,   --pk = ID, DATE, TIME, ID_mist
ID_Mist INT NOT NULL,
Datum TIMESTAMP NOT NULL,
CONSTRAINT MS_lek 
    FOREIGN KEY (ID_Lek, Datum) REFERENCES Lekce(ID_Lekce, Datum),
CONSTRAINT PK_ 
    PRIMARY KEY (ID_mist, Datum)
);
--TABULKA KLIENTSKA KARTA
CREATE TABLE Klientska_karta (
ID_karty INT GENERATED AS IDENTITY PRIMARY KEY
);

--TABULKA KLIENT
CREATE TABLE Klient (
ID_klienta INT GENERATED AS IDENTITY PRIMARY KEY,
Rodne_cislo CHAR(11) NOT NULL,
Jmeno VARCHAR(20) NOT NULL,
Prijmeni VARCHAR(20) NOT NULL,
Telefon VARCHAR(12) NOT NULL,
Email VARCHAR(40),
Ulice VARCHAR(40),
Cislo VARCHAR(40),
Mesto VARCHAR(40),
PSC VARCHAR(5),
ID_Tvurce INT NOT NULL,
ID_karty INT DEFAULT NULL,
CONSTRAINT klient_karta_FK FOREIGN KEY (ID_karty) REFERENCES Klientska_karta(ID_karty) ON DELETE SET NULL,
CONSTRAINT Klient_Recepcni FOREIGN KEY (ID_Tvurce) REFERENCES Recepcni(ID_rec) ON DELETE SET NULL
);

--TABULKA REZERVACE --> omezení­ kapacity lekcí řeší IS
CREATE TABLE Rezervace(
ID_Lekce INT NOT NULL,
ID_Klienta INT NOT NULL,
CONSTRAINT Rezervace_Lekce_FK
    FOREIGN KEY (ID_Lekce) REFERENCES Lekce(ID_Lekce) ON DELETE SET NULL,
CONSTRAINT Rezervace_Klient_FK
    FOREIGN KEY (ID_Klienta) REFERENCES Klient (ID_klienta) ON DELETE SET NULL,
CONSTRAINT ID_Rezervace
    PRIMARY KEY (ID_Klienta, ID_Lekce)
);

-- Trigger 1: automatické přidělení karty podle ID uživatele
CREATE OR REPLACE TRIGGER pridat_Kartu
	BEFORE INSERT ON Klient
	FOR EACH ROW
DECLARE
    id_kartyK INT;
BEGIN
	IF :NEW.ID_klienta IS NOT NULL THEN
        SELECT ID_karty INTO id_kartyK FROM Klientska_karta WHERE ID_Karty = :NEW.ID_Klienta;
        :NEW.ID_karty := id_kartyK;
	END IF;
END;
/
-- Trigger 2: automatické vymazání všech vázaných záznamů na instruktora
-- dojde-li ke smazání instruktora, dojde k vymazání jeho záznamů z tabulky kvalifikací
-- a dojde ke zrušení všech lekcí, které měl instruktor vést. Na základě toho dojde 
-- i ke zrušení příslušných rezervací.
CREATE OR REPLACE TRIGGER zrusLekce
    BEFORE DELETE ON Instruktor
    FOR EACH ROW
DECLARE
    lekce INT;
BEGIN
    DELETE FROM Rezervace WHERE ID_Lekce IN (SELECT ID_Lekce FROM Lekce WHERE ID_Instruktora = :old.ID_instruktora);
    DELETE FROM Individual WHERE ID_ind IN (SELECT ID_Lekce FROM Lekce WHERE ID_Instruktora = :old.ID_instruktora);
    DELETE FROM Skupinove WHERE ID_skup IN (SELECT ID_Lekce FROM Lekce WHERE ID_Instruktora = :old.ID_instruktora);
    DELETE FROM KvalifikaceInstruktora WHERE ID_instruktora = :old.ID_instruktora;
    DELETE FROM Lekce WHERE ID_instruktora = :old.ID_instruktora;
END;
/

-- Testování triggerů --
-- Trigger 1:
    -- viz INSERT na řádku: 232
    
-- Trigger 2:
    -- viz DELETE na řádku: 318

------------INSERT------------
--NAPLNĚNÍ TABULKY FIKTIVNÍMI DATY
INSERT INTO Recepcni (Pracovni_pomer) VALUES ('HPP');
INSERT INTO Recepcni (Pracovni_pomer) VALUES ('DPP');

INSERT INTO Instruktor VALUES(DEFAULT);
INSERT INTO Instruktor VALUES(DEFAULT);
INSERT INTO Instruktor VALUES(DEFAULT);

INSERT INTO Zamestnanec (Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, recepcni_ID, id_instruktora) 
VALUES ('000212/1234', 'Martin', 'Pech', '420605800432', 'dev@mpech.net', 1, 1);

INSERT INTO Zamestnanec (Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, recepcni_ID) 
VALUES ('000312/1234', 'David', 'Konečný', '420605811432', 'xkonec83@stud.fit.vutbr.cz', 2); -- Rodné číslo může být stejné (může se to stát ve vyjímečných případech)

INSERT INTO Zamestnanec (Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, id_instruktora)
VALUES ('989212/8888', 'Petr', 'Novák', '420288811311', 'petr@ttt.com', 2);

INSERT INTO Zamestnanec (Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, id_instruktora)
VALUES ('000100/0001', 'Jan', 'Vymyšlený', '420212354796', 'jan@notexists.cz', 3);

INSERT INTO Kvalifikace (Nazev, Popis) VALUES ('Kruhový trénink', 'Skupinová cvičení s váhou vlastního těla');
INSERT INTO Kvalifikace (Nazev, Popis) VALUES ('FitBox', 'Skupinová silová a kondiční cvičení boxu');
INSERT INTO Kvalifikace (Nazev, Popis) VALUES ('Kondiční posilování', 'Skupinové a kondiční posilování');

INSERT INTO KvalifikaceInstruktora(ID_instruktora, ID_kvalifikace)
VALUES (1, 1);

INSERT INTO KvalifikaceInstruktora(ID_instruktora, ID_kvalifikace)
VALUES (1, 2);

INSERT INTO KvalifikaceInstruktora(ID_instruktora, ID_kvalifikace)
VALUES (2, 2);

INSERT INTO KvalifikaceInstruktora(ID_instruktora, ID_kvalifikace)
VALUES (3, 1);

INSERT INTO Klientska_karta VALUES(DEFAULT);
INSERT INTO Klientska_karta VALUES(DEFAULT);
INSERT INTO Klientska_karta VALUES(DEFAULT);

-- Testování Triggeru 1:
INSERT INTO Klient(Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, Ulice, Cislo, Mesto, PSC, ID_Tvurce)
VALUES('000451/1234', 'Karel', 'Roden', '421765890453', 'kaja.roden@nejlepsiherci.cz', 'Na Výsluní', '12', 'Praha', '62100', 1);

INSERT INTO Klient(Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, Ulice, Cislo, Mesto, PSC, ID_Tvurce)
VALUES('000451/1234', 'Jaromír', 'Novák', '421765890452', 'jarek@xyz.cz', 'Na Barandově', '9', 'Praha', '62102', 1);


INSERT INTO Lekce (Datum, ID_instruktora) VALUES (TO_TIMESTAMP('02.10:2022 17:30:00', 'dd.mm.yyyy hh24:mi:ss'), 1);
INSERT INTO Lekce (Datum, ID_instruktora) VALUES (TO_TIMESTAMP('02.10:2022 18:30:00', 'dd.mm.yyyy hh24:mi:ss'), 1);
INSERT INTO Lekce (Datum) VALUES (TO_TIMESTAMP('02.10:2022 20:30:00', 'dd.mm.yyyy hh24:mi:ss'));
INSERT INTO Lekce (Datum) VALUES (TO_TIMESTAMP('02.10:2022 20:30:00', 'dd.mm.yyyy hh24:mi:ss'));

INSERT INTO Lekce (Datum, ID_instruktora) VALUES (TO_TIMESTAMP('02.10:2022 10:00:00', 'dd.mm.yyyy hh24:mi:ss'), 2);
INSERT INTO Lekce (Datum, ID_instruktora) VALUES (TO_TIMESTAMP('02.10:2022 12:30:00', 'dd.mm.yyyy hh24:mi:ss'), 2);
INSERT INTO Lekce (Datum, ID_instruktora) VALUES (TO_TIMESTAMP('12.10:2022 17:00:00', 'dd.mm.yyyy hh24:mi:ss'), 3);
INSERT INTO Lekce (Datum, ID_instruktora) VALUES (TO_TIMESTAMP('12.10:2022 17:00:00', 'dd.mm.yyyy hh24:mi:ss'), 2);
INSERT INTO Lekce (Datum, ID_instruktora) VALUES (TO_TIMESTAMP('02.01:2021 13:00:00', 'dd.mm.yyyy hh24:mi:ss'), 2);

INSERT INTO Skupinove (Nazev, ID_skup) VALUES('Jumping', 2);
INSERT INTO Skupinove (Nazev, ID_skup) VALUES('Jumping', 3);
INSERT INTO Individual (ID_ind) VALUES(2);

INSERT INTO Mistnost(Oznaceni, Umisteni, Kapacita) 
VALUES ('VS3', '1NP', '30');
INSERT INTO Mistnost(Oznaceni, Umisteni, Kapacita) 
VALUES ('MS1', '0NP', '10');
INSERT INTO Mistnost(Oznaceni, Umisteni, Kapacita) 
VALUES ('MS2', '0NP', '10');

INSERT INTO MistnostSkupina(ID_mist, Datum)
VALUES (1, '02.10:2022 17:30:00');

INSERT INTO MistnostSkupina(ID_mist, Datum)
VALUES (1, '03.10:2022 17:30:00');

INSERT INTO Rezervace (ID_Lekce, ID_Klienta) 
VALUES (1, 1);

INSERT INTO Rezervace (ID_Lekce, ID_Klienta) 
VALUES (2, 2);

INSERT INTO Rezervace (ID_Lekce, ID_Klienta) 
VALUES (1, 2);



------------SELECT------------
-- 2 selecty s joinem dvou tabulek          [2/2]
-- 1 select s joinem tří tabulek            [1/1]
-- 2 selecty s GROUP BY a agregační funkcí  [2/2]
-- 1 select s EXISTS                        [1/1]
-- 1 select s IN a vnořeným selectem        [1/1]


-- Vyber všechny zaměstnance, kteří vedou lekci dne 12.10.2022
SELECT jmeno, prijmeni, id_lekce FROM zamestnanec NATURAL JOIN lekce 
WHERE datum >= TO_TIMESTAMP('12.10:2022 00:00:00', 'dd.mm.yyyy hh24:mi:ss') and datum <= TO_TIMESTAMP('12.10:2022 23:59:59', 'dd.mm.yyyy hh24:mi:ss');


-- Vyber všechny zaměstnance, kteří jsou instruktoři a jejichž kvalifikací je FitBox
SELECT jmeno, prijmeni, nazev FROM zamestnanec NATURAL JOIN kvalifikace NATURAL JOIN kvalifikaceinstruktora
WHERE id_instruktora IS NOT NULL AND nazev = 'FitBox';


-- Vyber všechny klienty, kteří mají (nebo měli) zarezervovány právě dvě lekce
SELECT jmeno, prijmeni, COUNT(*) AS pocet_lekci FROM klient NATURAL JOIN rezervace
GROUP BY jmeno, prijmeni HAVING COUNT(id_lekce) = 2;

-- Vyber všechny místnosti, kde neprobíhá výuka před 18:00
SELECT DISTINCT oznaceni, kapacita FROM mistnost NATURAL JOIN skupinove NATURAL JOIN mistnostskupina
WHERE CAST(datum AS TIME) < '18:00:00';

-- Vyber všechny lekce, které ještě nemají přiděleného trenéra
SELECT ID_Lekce AS "Nepřidělené lekce" FROM Lekce
WHERE NOT EXISTS (SELECT * FROM Zamestnanec
WHERE zamestnanec.id_instruktora = Lekce.ID_Instruktora) ORDER BY ID_lekce;

-- Vyber všechny zaměstnance se dvěma a více kvalifikacemi 
SELECT jmeno, prijmeni, COUNT(*) AS "Kvalifikace instruktora" FROM zamestnanec NATURAL JOIN kvalifikaceinstruktora
GROUP BY jmeno, prijmeni HAVING COUNT(id_kvalifikace) > 1;

-- Vyber ID Lekcí, které jsou lekce individuální
SELECT ID_Lekce FROM Lekce
WHERE ID_Lekce IN (SELECT ID_ind FROM Individual);

-- Testování Triggeru 2:
DELETE FROM Instruktor WHERE ID_instruktora = 1;
--

-- Procedura
-- Procedura vypíše celkový počet instruktorů a jejich kvalifikací
SET SERVEROUTPUT ON;
CREATE OR REPLACE PROCEDURE InstruktorStats
AS
    pocetInstr INT;
    kvalifikaceInst INT;
    idInst INT;
    CURSOR instruktori IS SELECT ID_Instruktora FROM Instruktor;
    namem int;
    iName varchar(100);
    iPrijmeni varchar(100);
   
BEGIN
    SELECT COUNT(*) INTO pocetInstr FROM Instruktor;
    open instruktori;
        LOOP 
            FETCH instruktori INTO idInst;
            EXIT WHEN instruktori%NOTFOUND;
            SELECT COUNT(*) INTO namem FROM KvalifikaceInstruktora WHERE ID_instruktora = idInst;
            DBMS_OUTPUT.put_line('Instruktor '|| idInst || ' má '|| namem || ' kvalifikací.');
        END LOOP;
    close instruktori;
    
    EXCEPTION WHEN NO_DATA_FOUND THEN
	BEGIN
		DBMS_OUTPUT.put_line('Nic víc k výpisu.');
	END;

END;
/
CALL InstruktorStats();

-- Procedura
-- Procedura vypíše umístění všech místností
CREATE OR REPLACE PROCEDURE MistnostiUmisteni
AS
    IDMistnosti Mistnost.ID_Mistnosti%TYPE;
    CURSOR magicLoop IS SELECT ID_Mistnosti FROM Mistnost;
    misto Mistnost.Umisteni%TYPE;
BEGIN
    open magicLoop;
    LOOP
        FETCH magicLoop INTO IDMistnosti;
        EXIT WHEN magicLoop%NOTFOUND;
        
        SELECT Umisteni INTO misto FROM Mistnost WHERE ID_Mistnosti = IDMistnosti;
    
        DBMS_OUTPUT.put_line('Mistnost s ID: ' || IDMistnosti || ' se nachazi v ' || misto || ' (NP znaci nadzemni patro)');
    END LOOP;
    close magicLoop;
END;
/
CALL MistnostiUmisteni();


-- Explain plan
EXPLAIN PLAN FOR 
SELECT ID_Kvalifikace, COUNT(ID_Instruktora) as ID_Kv FROM KvalifikaceInstruktora NATURAL JOIN Instruktor GROUP BY KvalifikaceInstruktora.ID_Kvalifikace;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

CREATE INDEX KvalInst ON KvalifikaceInstruktora (ID_Kvalifikace);
    
EXPLAIN PLAN FOR 
SELECT ID_Kvalifikace, COUNT(ID_Instruktora) as ID_Kv FROM KvalifikaceInstruktora NATURAL JOIN Instruktor GROUP BY KvalifikaceInstruktora.ID_Kvalifikace;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
    

-- Materializovaný pohled pro zobrazení kvalifikací instruktorů
CREATE MATERIALIZED VIEW ZamestanecKvalifikaci AS
SELECT jmeno, prijmeni, nazev AS kvalifikace FROM zamestnanec NATURAL JOIN KvalifikaceINstruktora NATURAL JOIN Kvalifikace WHERE id_instruktora IS NOT NULL;

SELECT * FROM ZamestanecKvalifikaci;

UPDATE kvalifikaceinstruktora SET ID_kvalifikace = 1 WHERE id_instruktora = 2;
-- Petr Novák má nyní kvalifikaci Kruhový trénink
SELECT jmeno, prijmeni, id_instruktora, nazev AS kvalifikace FROM zamestnanec NATURAL JOIN KvalifikaceINstruktora NATURAL JOIN Kvalifikace WHERE id_instruktora IS NOT NULL;
-- V Materializovaném pohledu mu však zůstala kvalifikace FitBox
SELECT * FROM ZamestanecKvalifikaci;


--------------Oprávnění druhému uživateli--------------
GRANT ALL ON Zamestnanec TO xkonec83;
GRANT ALL ON KvalifikaceInstruktora TO xkonec83;
GRANT ALL ON Kvalifikace TO xkonec83;
GRANT ALL ON Individual TO xkonec83;
GRANT ALL ON MistnostSkupina TO xkonec83;
GRANT ALL ON Mistnost TO xkonec83;
GRANT ALL ON Skupinove TO xkonec83;
GRANT ALL ON Rezervace TO xkonec83;
GRANT ALL ON Lekce TO xkonec83;
GRANT ALL ON Instruktor TO xkonec83;
GRANT ALL ON Klient TO xkonec83;
GRANT ALL ON Recepcni TO xkonec83;
GRANT ALL ON Klientska_karta TO xkonec83;
GRANT ALL ON ZamestanecKvalifikaci TO xkonec83;


------------Pokročilé objekty------------
-- 2 netriviální databázové triggery vč. jejich předvedení                                                  [2/2]
-- 2 netriviální uložené procedury vč. jejich předvedení                                                    [2/2]
-- 1 index pro optimalizování dotazů                                                                        [1/1]
-- 1 EXPLAIN PLAN se spojením alespoň dvou tabulek, agregační funkcí a klauzulí GROUP BY (s optimalizací)   [1/1]
-- 1 definice přístupových práv k databázovým objektům pro druhého člena týmu                               [1/1]
-- 1 materializovaný pohled patřící druhému členu týmu a používající tabulky definované prvním členem týmu  [1/1]
