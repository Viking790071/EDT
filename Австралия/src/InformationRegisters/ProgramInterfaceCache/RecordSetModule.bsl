#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Variables

Var VerificationRequired;
Var DataToWrite;
Var PreparedData;

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// There is no DataExchange.Load property value verification, because the limitations imposed by the 
	// script should not be bypassed by passing True to the Load property (on the side of the script 
	// that records to this register).
	//
	// This register cannot be included in any exchanges or data import or export operations if the data 
	// area separation is enabled.
	
	If PreparedData Then
		Load(DataToWrite);
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	// There is no DataExchange.Load property value verification, because the limitations imposed by the 
	// script should not be bypassed by passing True to the Load property (on the side of the script 
	// that records to this register).
	//
	// This register cannot be included in any exchanges or data import or export operations if the data 
	// area separation is enabled.
	
	If VerificationRequired Then
		
		For Each Record In ThisObject Do
			
			VerificationRows = DataToWrite.FindRows(
				New Structure("ID, DataType", Record.ID, Record.DataType));
			
			If VerificationRows.Count() <> 1 Then
				VerificationError();
			Else
				
				VerificationRow = VerificationRows.Get(0);
				
				CurrentData = Common.ValueToXMLString(Record.Data.Get());
				VerificationData = Common.ValueToXMLString(VerificationRow.Data.Get());
				
				If CurrentData <> VerificationData Then
					VerificationError();
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure PrepareDataToRecord() Export
	
	ReceivingParameters = Undefined;
	If Not AdditionalProperties.Property("ReceivingParameters", ReceivingParameters) Then
		Raise NStr("ru = 'Не определены параметры получения данных'; en = 'The data getting parameters are not defined.'; pl = 'Nie określono parametrów uzyskania danych';es_ES = 'Parámetros del recibo de datos no se han especificado';es_CO = 'Parámetros del recibo de datos no se han especificado';tr = 'Veri girişi parametreleri belirtilmemiş';it = 'Parametri non definiti per la ricezione di dati.';de = 'Datenempfangsparameter sind nicht angegeben'");
	EndIf;
	
	DataToWrite = Unload();
	
	For Each Row In DataToWrite Do
		
		Data = InformationRegisters.ProgramInterfaceCache.PrepareVersionCacheData(Row.DataType, ReceivingParameters);
		Row.Data = New ValueStorage(Data);
		
	EndDo;
	
	PreparedData = True;
	
EndProcedure

Procedure VerificationError()
	
	Raise NStr("ru = 'Недопустимое изменение ресурса Данные записи регистра сведений ProgramInterfaceCache
                            |внутри транзакции записи из сеанса с включенным разделением.'; 
                            |en = 'The Data resource of the ProgramInterfaceCache information register record cannot be changed
                            |inside the record transaction from the session with separation enabled.'; 
                            |pl = 'Zasób danych w rejestrze informacji ProgramInterfaceCache information nie może być zmieniony
                            |w zapisie transakcji z sesji z włączonym splitem.';
                            |es_ES = 'No se admite cambiar el recurso Datos de guardar el registro de información ProgramInterfaceCache
                            |dentro de transacción del registro de la sesión con la separación activada.';
                            |es_CO = 'No se admite cambiar el recurso Datos de guardar el registro de información ProgramInterfaceCache
                            |dentro de transacción del registro de la sesión con la separación activada.';
                            |tr = 'Kabul edilemez kaynak güncellemesi Bilgi kayıt cihazı verileri
                            | ProgramArayüzüÖnbellek etkinleştirilmiş bölümlü oturumdan kayıt işlemi içinde!';
                            |it = 'Risultato non valido della risorsa. I dati del registro delle informazioni CacheInterfacceProgrammi 
                            | all''interno di una voce di transazione da una sessione con distribuzione inclusa.';
                            |de = 'Unzulässige Änderung der Ressourcendaten des Datenregistersatzes ProgramInterfaceCache
                            |innerhalb der Transaktion des Datensatzes aus der Sitzung bei aktivierter Aufteilung.'");
	
EndProcedure

#EndRegion

#Region Initializing

DataToWrite = New ValueTable();
VerificationRequired = Common.DataSeparationEnabled() AND Common.SeparatedDataUsageAvailable();
PreparedData = False;

#EndRegion

#EndIf
