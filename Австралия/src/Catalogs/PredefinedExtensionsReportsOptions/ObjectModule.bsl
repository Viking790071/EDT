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
		Raise NStr("ru = 'Справочник ""Предопределенные варианты отчетов"" изменяется только при автоматическом заполнении его данных.'; en = 'The ""Predefined report options"" catalog is changed only when data is filled in automatically.'; pl = 'Katalog ""Predefiniowane opcje sprawozdania"" zmienia się tylko wtedy, gdy dane są wypełniane automatycznie.';es_ES = 'El catálogo de las ""Opciones del informe predefinido"" se ha cambiado solo cuando los datos están rellenados automáticamente.';es_CO = 'El catálogo de las ""Opciones del informe predefinido"" se ha cambiado solo cuando los datos están rellenados automáticamente.';tr = '""Öntanımlı rapor seçenekleri"" kataloğu sadece veriler otomatik doldurulduğunda değiştirilir.';it = 'La anagrafica ""Varianti di report predefinite"" è cambiato in automatico solo quando i dati sono compilati.';de = 'Der Katalog ""Vordefinierte Berichtsoptionen"" wird nur geändert, wenn Daten automatisch ausgefüllt werden.'");
	EndIf;
EndProcedure

// Basic validation of predefined report option data. 
Procedure CheckFillingOfPredefined(Cancel)
	If DeletionMark Then
		Return;
	ElsIf Not ValueIsFilled(Report) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не заполнено поле ""%1""'; en = 'The ""%1"" field is not filled in'; pl = 'Pole ""%1"" nie jest wypełnione';es_ES = 'El ""%1"" campo no está rellenado';es_CO = 'El ""%1"" campo no está rellenado';tr = '""%1"" alanı doldurulmadı';it = 'Il campo ""%1"" non è compilato';de = 'Das Feld ""%1"" ist nicht ausgefüllt'"), "Report");
	Else
		Return;
	EndIf;
EndProcedure

#EndRegion

#EndIf