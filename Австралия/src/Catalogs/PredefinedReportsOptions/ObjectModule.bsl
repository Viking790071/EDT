#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	If AdditionalProperties.Property("PredefinedObjectsFilling") Then
		CheckFillingOfPredefined(Cancel);
	EndIf;
	If DataExchange.Load Then
		Return;
	EndIf;
	If Not AdditionalProperties.Property("PredefinedObjectsFilling") Then
		Raise NStr("ru = 'Запись в справочник ""Предопределенные варианты отчетов"" запрещена. Его данные заполняются автоматически.'; en = 'Cannot write to the ""Predefined report options"" catalog. Its data is filled in automatically.'; pl = 'Zapisywanie do katalogu ""Opcje predefiniowanych raportów"" jest zabroniona. Jego dane są wypełniane automatycznie.';es_ES = 'Está prohibido guardar en el catálogo ""Variantes de informes predeterminadas"". Sus datos se rellenan automáticamente.';es_CO = 'Está prohibido guardar en el catálogo ""Variantes de informes predeterminadas"". Sus datos se rellenan automáticamente.';tr = '""Önceden tanımlanmış rapor seçenekleri"" dizinine yazma yasaktır. Verileri otomatik olarak doldurulur.';it = 'Impossibile registrare nella anagrafica ""Varianti di report predefinite"". I suoi dati sono compilati in maniera automatica.';de = 'Der Eintrag in das Verzeichnis ""Vordefinierte Varianten von Berichten"" ist verboten. Seine Daten werden automatisch ausgefüllt.'");
	EndIf;
EndProcedure

// Basic validation of predefined report option data. 
Procedure CheckFillingOfPredefined(Cancel)
	
	If DeletionMark Then
		Return;
	EndIf;
	If ValueIsFilled(Report) Then
		Return;
	EndIf;
		
	Raise NStr("ru = 'Не заполнено поле ""Отчет""'; en = 'The Report field is required'; pl = 'Nie wypełniono pola ""Raport""';es_ES = 'El campo ""Informe"" no rellenado';es_CO = 'El campo ""Informe"" no rellenado';tr = '""Rapor"" alanı doldurulmadı';it = 'Il campo Report è obbligatorio';de = 'Das Feld ""Bericht"" ist nicht ausgefüllt'");
	
EndProcedure

#EndRegion

#EndIf