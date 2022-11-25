
#Region ProcedureFormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Query = New Query(
	"SELECT ALLOWED
	|	CatalogPeripherals.Ref AS Device,
	|	CatalogPeripherals.EquipmentType AS EquipmentType
	|FROM
	|	Catalog.Peripherals AS CatalogPeripherals
	|		INNER JOIN Catalog.CashRegisters AS CashRegisters
	|		ON (CashRegisters.Peripherals = CatalogPeripherals.Ref)
	|WHERE
	|	CatalogPeripherals.EquipmentType = VALUE(Enum.PeripheralTypes.CashRegistersOffline)
	|	AND CatalogPeripherals.ExchangeRule <> VALUE(Catalog.ExchangeWithOfflinePeripheralsRules.EmptyRef)
	|	AND CatalogPeripherals.DeviceIsInUse
	|
	|UNION ALL
	|
	|SELECT
	|	CatalogPeripherals.Ref,
	|	CatalogPeripherals.EquipmentType
	|FROM
	|	Catalog.Peripherals AS CatalogPeripherals
	|WHERE
	|	CatalogPeripherals.EquipmentType = VALUE(Enum.PeripheralTypes.LabelsPrintingScales)
	|	AND CatalogPeripherals.ExchangeRule <> VALUE(Catalog.ExchangeWithOfflinePeripheralsRules.EmptyRef)
	|	AND CatalogPeripherals.DeviceIsInUse");
	
	Query.SetParameter("CurrentWorksPlace", Parameters.Workplace);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		NewRow = Equipment.Add();
		NewRow.ExecuteExchange         = True;
		NewRow.Device                  = Selection.Device;
		NewRow.EquipmentType           = Selection.EquipmentType;
		NewRow.ExportStatus          = NStr("en = '<Export was not made>'; ru = '<Выгрузка не производилась>';pl = '<Eksport nie został wykonany>';es_ES = '<Exportación no se ha hecho>';es_CO = '<Exportación no se ha hecho>';tr = '<Dışa aktarma yapılmadı>';it = '<L''esportazione non è stata effettuata>';de = '<Export wurde nicht durchgeführt>'");
		NewRow.ImportingPictureIndex   = 1;
		NewRow.ExportingPictureIndex = 1;
		
		If NewRow.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales Then
			NewRow.ImportStatus = NStr("en = '<Not needed>'; ru = '<Не требуется>';pl = '<Nie jest konieczne>';es_ES = '<No es necesario>';es_CO = '<Not needed>';tr = '<Gerekli değil>';it = '<Non necessario>';de = '<Nicht erforderlich>'");
		Else
			NewRow.ImportStatus = NStr("en = '<Import was not made>'; ru = '<Загрузка не производилась>';pl = '<Import nie został wykonany>';es_ES = '<Importación no se ha hecho>';es_CO = '<Importación no se ha hecho>';tr = '<İçe aktarma yapılmadı>';it = '<Importazione non effettuata>';de = '<Import wurde nicht durchgeführt>'");
		EndIf;
		
	EndDo;
	
	State = "";
	
	Items.Start.Enabled              = True;
	Items.Complete.Enabled           = False;
	
EndProcedure

#EndRegion

#Region ProcedureCommandHandlers

&AtClient
Procedure Start(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(ExchangePeriodicity) Then
		CommonClientServer.MessageToUser(NStr("en = 'Frequency of exchange with equipment is not specified'; ru = 'Не задана периодичность обмена с оборудованием';pl = 'Częstotliwość wymiany z urządzeniami peryferyjnymi nie jest określona';es_ES = 'Frecuencia del intercambio con el equipamiento no se ha especificado';es_CO = 'Frecuencia del intercambio con el equipamiento no se ha especificado';tr = 'Ekipman ile değişim sıklığı belirlenmemiş';it = 'La frequenza di scambio con le apparecchiature non è specificata';de = 'Die Frequenz des Austausches mit der Ausrüstung ist nicht angegeben'"),,"ExchangePeriodicity");
		Return;
	EndIf;
	
	If Not IsEquipmentForExchange() Then
		CommonClientServer.MessageToUser(NStr("en = 'Equipment for exchange is not selected'; ru = 'Не выбрано оборудование для обмена';pl = 'Nie wybrano urządzeń peryferyjnych do wymiany';es_ES = 'Equipamiento para el intercambio no se ha seleccionado';es_CO = 'Equipamiento para el intercambio no se ha seleccionado';tr = 'Değişim için ekipman seçilmemiş';it = 'Apparecchiatura  per lo scambio non selezionata';de = 'Ausrüstung für den Austausch ist nicht ausgewählt'"),,"Equipment");
		Return;
	EndIf;
	
	Items.ExchangePeriodicity.Enabled              = False;
	Items.EquipmentExecuteExchange.Enabled         = False;
	Items.EquipmentCheckAll.Enabled                = False;
	Items.EquipmentUncheckAll.Enabled              = False;
	Items.EquipmentContextMenuCheckAll.Enabled     = False;
	Items.EquipmentContextMenuUncheckAll.Enabled   = False;
	
	Items.Start.Enabled              = False;
	Items.Complete.Enabled           = True;
	
	State = NStr("en = 'Exchange with the peripherals is being performed...'; ru = 'Выполняется обмен с подключенным оборудованием...';pl = 'Trwa wymiana z urządzeniami peryferyjnymi...';es_ES = 'Intercambio con los periféricos se está realizando...';es_CO = 'Intercambio con los periféricos se está realizando...';tr = 'Bağlanan ekipman ile değişim gerçekleştiriliyor...';it = 'Scambio con le periferiche in corso...';de = 'Der Austausch mit den Peripheriegeräten wird durchgeführt...'");
	
	AttachIdleHandler("ExchangeExpectationsHandler", ExchangePeriodicity * 60, False);
	
	ExchangeInProgress = True;
	
EndProcedure

&AtClient
Procedure Complete(Command)
	
	Items.ExchangePeriodicity.Enabled             = True;
	Items.EquipmentExecuteExchange.Enabled        = True;
	Items.EquipmentCheckAll.Enabled               = True;
	Items.EquipmentUncheckAll.Enabled             = True;
	Items.EquipmentContextMenuCheckAll.Enabled    = True;
	Items.EquipmentContextMenuUncheckAll.Enabled  = True;
	
	Items.Start.Enabled              = True;
	Items.Complete.Enabled           = False;
	
	State = NStr("en = 'Exchange completed.'; ru = 'Обмен завершен.';pl = 'Wymiana zakończona.';es_ES = 'Intercambio finalizado.';es_CO = 'Intercambio finalizado.';tr = 'Değişim tamamlandı.';it = 'Scambio completato.';de = 'Austausch abgeschlossen.'");
	
	DetachIdleHandler("ExchangeExpectationsHandler");
	
	ExchangeInProgress = False;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If ExchangeInProgress Then
		
		If Exit Then
			WarningText = NStr("en = 'Exchange will be terminated'; ru = 'Обмен будет прекращен';pl = 'Wymiana zostanie przerwana';es_ES = 'Intercambio se finalizará';es_CO = 'Intercambio se finalizará';tr = 'Değişim sonlandırılacak';it = 'Lo scambio sarà terminato';de = 'Austausch wird beendet'");
		Else
			ShowMessageBox(, NStr("en = 'After the form is closed, exchange with equipment will not be performed.'; ru = 'После закрытия формы обмен с оборудованием выполняться не будет.';pl = 'Po zamknięciu formularza wymiana z urządzeniami nie zostanie wykonana.';es_ES = 'Después de haber cerrado el formulario, el intercambio con el equipamiento no se realizará.';es_CO = 'Después de haber cerrado el formulario, el intercambio con el equipamiento no se realizará.';tr = 'Form kapatıldıktan sonra ekipman değişimi yapılmayacaktır.';it = 'Dopo che il modulo sarà chiuso, lo scambio con il dispositivo non sarà eseguito.';de = 'Nachdem das Formular geschlossen wurde, wird der Austausch mit dem Gerät nicht durchgeführt.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	SetCheckboxesOnServer();
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	RemoveCheckboxesOnServer();
EndProcedure

&AtClient
Procedure ExecuteNow(Command)
	
	State = NStr("en = 'Exchange with the peripherals is being performed...'; ru = 'Выполняется обмен с подключенным оборудованием...';pl = 'Trwa wymiana z urządzeniami peryferyjnymi...';es_ES = 'Intercambio con los periféricos se está realizando...';es_CO = 'Intercambio con los periféricos se está realizando...';tr = 'Bağlanan ekipman ile değişim gerçekleştiriliyor...';it = 'Scambio con le periferiche in corso...';de = 'Der Austausch mit den Peripheriegeräten wird durchgeführt...'");
	RunExchange();
	State = NStr("en = 'Exchange completed.'; ru = 'Обмен завершен.';pl = 'Wymiana zakończona.';es_ES = 'Intercambio finalizado.';es_CO = 'Intercambio finalizado.';tr = 'Değişim tamamlandı.';it = 'Scambio completato.';de = 'Austausch abgeschlossen.'");
	
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure RunExchange()
	
	For Each TSRow In Equipment Do
		
		If Not TSRow.ExecuteExchange Then
			Continue;
		EndIf;
		
		DeviceArray = New Array;
		DeviceArray.Add(TSRow.Device);
		
		// Data export
		MessageText = "";
		NotificationOnImplementation = New NotifyDescription(
			"ExecuteExchangeEnd",
			ThisObject,
			New Structure ("MessageText, TSRow, DeviceArray", MessageText, TSRow, DeviceArray)
		);
		
		PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(TSRow.EquipmentType, DeviceArray, MessageText, False, NotificationOnImplementation, True);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ExecuteExchangeEnd(Result, Parameters) Export
	
	Parameters.TSRow.ExportStatus = Parameters.MessageText;
	Parameters.TSRow.ExportingPictureIndex = ?(Result, 1, 0);
	Parameters.TSRow.ExportEndDate = CommonClient.SessionDate();
	
	// Data Import
	If Parameters.TSRow.EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
		
		MessageText = "";
		
		NotificationOnImplementation = New NotifyDescription(
			"ExecuteImportEnd",
			ThisObject,
			Parameters
		);
		
		PeripheralsOfflineClient.AsynchronousImportReportAboutRetailSales(Parameters.DeviceArray,,, NotificationOnImplementation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteImportEnd(Result, Parameters) Export
	
	Parameters.TSRow.ExportStatus = Parameters.MessageText;
	Parameters.TSRow.ExportingPictureIndex = ?(Result, 1, 0);
	Parameters.TSRow.ExportEndDate = CommonClient.SessionDate();
	
EndProcedure

&AtClient
Procedure ExchangeExpectationsHandler()
	
	RunExchange();
	
	DetachIdleHandler("ExchangeExpectationsHandler");
	AttachIdleHandler("ExchangeExpectationsHandler", ExchangePeriodicity * 60, False);
	
EndProcedure

&AtServer
Procedure SetCheckboxesOnServer()
	
	For Each TSRow In Equipment Do
		TSRow.ExecuteExchange = True;
	EndDo;
	
EndProcedure

&AtServer
Procedure RemoveCheckboxesOnServer()
	
	For Each TSRow In Equipment Do
		TSRow.ExecuteExchange = False;
	EndDo;
	
EndProcedure

&AtServer
Function IsEquipmentForExchange()
	
	Return Equipment.FindRows(New Structure("ExecuteExchange", True)).Count() > 0;
	
EndFunction

#EndRegion
