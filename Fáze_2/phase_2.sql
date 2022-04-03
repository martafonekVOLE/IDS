-- SQL Skript na vytvoøení základních struktury databáze a naplnìní jí fiktivními daty
-- Autor: Martin Pech (xpechm00)
-- Autor: David Koneèný (xkonec83)

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


------------CREATE------------
--TABULKA RECEPCNI - GENERALIZACE Z TABULKY ZAMESTNANCE
CREATE TABLE Recepcni (
ID_rec INT GENERATED AS IDENTITY PRIMARY KEY,
Pracovni_pomer VARCHAR(20) --Nìjaký option?
);

--TABULKA INSTRUKTOR - GENERALIZACE Z TABULKY ZAMESTNANCE
CREATE TABLE Instruktor(
ID_inst INT GENERATED AS IDENTITY PRIMARY KEY
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
Instruktor_ID INT DEFAULT NULL,
CONSTRAINT zamestnanec_recepcni_FK FOREIGN KEY (Recepcni_ID) REFERENCES Recepcni (ID_rec) ON DELETE SET NULL,
CONSTRAINT zamestnanec_instruktor_FK FOREIGN KEY (Instruktor_ID) REFERENCES Instruktor (ID_inst) ON DELETE SET NULL
);

--TABULKA KVALIFIKACE
CREATE TABLE Kvalifikace(
ID_kvalifikace INT GENERATED AS IDENTITY PRIMARY KEY,
Nazev VARCHAR (40) NOT NULL,
Popis VARCHAR (100)
);

--TABULKA KVALIFIKACE INSTRUKTORA
CREATE TABLE KvalifikaceInstruktora(
ID_instruktor INT NOT NULL,
ID_kvalifikace INT NOT NULL,
CONSTRAINT instruktor_kvalifikace_PK 
    PRIMARY KEY (ID_instruktor, ID_kvalifikace),
CONSTRAINT instruktor_KI_FK
    FOREIGN KEY (ID_instruktor) REFERENCES Instruktor(ID_inst),
CONSTRAINT kvalifikace_KI_FK
    FOREIGN KEY (ID_kvalifikace) REFERENCES Kvalifikace(ID_kvalifikace)
);

--TABULKA LEKCE
CREATE TABLE Lekce(
ID_Lekce INT GENERATED AS IDENTITY PRIMARY KEY, --formát + ID_Mistnosti(2) +  4 unikátní èísla          --pøidat jméno?
Datum TIMESTAMP NOT NULL,
ID_inst INT,
CONSTRAINT ID_gen UNIQUE(ID_Lekce, Datum),
CONSTRAINT Instruktor_Lekce 
    FOREIGN KEY(ID_inst) REFERENCES Instruktor(ID_inst)
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
Kapacita VARCHAR(2) NOT NULL
    CHECK(REGEXP_LIKE(Kapacita, '^[0-9][0-9]$')),
CONSTRAINT Skup_Lekce_FK
    FOREIGN KEY (ID_skup) REFERENCES Lekce (ID_Lekce)
);

--TABULKA MISTNOST
CREATE TABLE Mistnost(
ID_Mistnosti INT GENERATED AS IDENTITY PRIMARY KEY,
Oznaceni VARCHAR(20),
Umisteni VARCHAR(20),
Kapacita VARCHAR(2) NOT NULL
    CHECK(REGEXP_LIKE(Kapacita, '^[0-9][0-9]$'))
);

--TABULKA MISTNOSTSKUPINA
CREATE TABLE MistnostSkupina(
ID_Lek INT,   --pk = ID, DATE, TIME, ID_room
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

--TABULKA REZERVACE --> omezení kapacity lekcí øeší IS
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


------------INSERT------------
--NAPLNÌNÍ TABULKY FIKTIVNÍMI DATY
INSERT INTO Recepcni (Pracovni_pomer) VALUES ('HPP');
INSERT INTO Recepcni (Pracovni_pomer) VALUES ('DPP');

INSERT INTO Instruktor VALUES(DEFAULT);

INSERT INTO Zamestnanec (Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, recepcni_ID, instruktor_ID) 
VALUES ('000212/1234', 'Martin', 'Pech', '420605800432', 'dev@mpech.net', 1, 1);

INSERT INTO Zamestnanec (Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, recepcni_ID) 
VALUES ('000312/1234', 'David', 'Koneèný', '420605811432', 'xkonec83@stud.fit.vutbr.cz', 2); -- Rodné èíslo mùže být stejné (mùže se to stát ve vyjímeèných pøípadech)

INSERT INTO Kvalifikace (Nazev, Popis) VALUES ('Kruhový trénink', 'Skupinové cvièení s váhou vlastního tìla');
INSERT INTO Kvalifikace (Nazev, Popis) VALUES ('FitBox', 'Skupinové silové a kondièní cvièení boxu');

INSERT INTO KvalifikaceInstruktora(ID_instruktor, ID_kvalifikace)
VALUES (1, 1);
INSERT INTO KvalifikaceInstruktora(ID_instruktor, ID_kvalifikace)
VALUES (1, 2);

INSERT INTO Klientska_karta VALUES(DEFAULT);
INSERT INTO Klientska_karta VALUES(DEFAULT);
INSERT INTO Klientska_karta VALUES(DEFAULT);

INSERT INTO Klient(Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, Ulice, Cislo, Mesto, PSC, ID_karty, ID_Tvurce)
VALUES('000451/1234', 'Karel', 'Roden', '421765890453', 'kaja.roden@nejlepsiherci.cz', 'Na Výsluní', '12', 'Praha', '62100', 1, 1);

INSERT INTO Klient(Rodne_cislo, Jmeno, Prijmeni, Telefon, Email, Ulice, Cislo, Mesto, PSC, ID_karty, ID_Tvurce)
VALUES('000451/1234', 'Jaromír', 'Novák', '421765890452', 'jarek@xyz.cz', 'Na Barandovì', '9', 'Praha', '62102', 2, 1);

INSERT INTO Lekce (Datum, ID_inst) VALUES (TO_TIMESTAMP('02.10:2022 17:30:00', 'dd.mm.yyyy hh24:mi:ss'), 1);
INSERT INTO Lekce (Datum, ID_inst) VALUES (TO_TIMESTAMP('02.10:2022 18:30:00', 'dd.mm.yyyy hh24:mi:ss'), 1);
INSERT INTO Lekce (Datum) VALUES (TO_TIMESTAMP('02.10:2022 20:30:00', 'dd.mm.yyyy hh24:mi:ss'));
INSERT INTO Lekce (Datum) VALUES (TO_TIMESTAMP('02.10:2022 20:30:00', 'dd.mm.yyyy hh24:mi:ss'));

INSERT INTO Skupinove (Nazev, Kapacita, ID_skup) VALUES('Jumping', '20', 1);
INSERT INTO Skupinove (Nazev, Kapacita, ID_skup) VALUES('Jumping', '10', 3);
INSERT INTO Individual (ID_ind) VALUES(2);

INSERT INTO Mistnost(Oznaceni, Umisteni, Kapacita) 
VALUES ('VS3', '1NP', '30');
INSERT INTO Mistnost(Oznaceni, Umisteni, Kapacita) 
VALUES ('MS1', '0NP', '10');

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
