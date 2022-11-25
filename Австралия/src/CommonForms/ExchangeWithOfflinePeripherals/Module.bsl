
#Region ProcedureFormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Workplace = EquipmentManagerServerCall.GetClientWorkplace();
	
	Scales.Parameters.SetParameterValue("CurrentWorksPlace", Workplace);
	CashRegisters.Parameters.SetParameterValue("CurrentWorksPlace", Workplace);
	
	SetConditionalAppearance();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	WarehouseCROffline = Settings.Get("WarehouseCROffline");
	WarehouseScales = Settings.Get("WarehouseScales");
	
	ExchangeRuleScales = Settings.Get("ExchangeRuleScales");
	CROfflineExchangeRule = Settings.Get("CROfflineExchangeRule");
	
	CommonClientServer.SetFilterItem(CashRegisters.Filter, "Warehouse", WarehouseCROffline, DataCompositionComparisonType.Equal,, ValueIsFilled(WarehouseCROffline));
	CommonClientServer.SetFilterItem(CashRegisters.Filter, "ExchangeRule", CROfflineExchangeRule, DataCompositionComparisonType.Equal,, ValueIsFilled(CROfflineExchangeRule));
	CommonClientServer.SetFilterItem(Scales.Filter, "Warehouse", WarehouseScales, DataCompositionComparisonType.Equal,, ValueIsFilled(WarehouseScales));
	CommonClientServer.SetFilterItem(Scales.Filter, "ExchangeRule", ExchangeRuleScales, DataCompositionComparisonType.Equal,, ValueIsFilled(ExchangeRuleScales));
	
	CommonClientServer.SetFilterItem(Scales.Filter, "ConnectedToCurrentWorksplace", True, DataCompositionComparisonType.Equal,, AllEquipmentScales = False);
	CommonClientServer.SetFilterItem(CashRegisters.Filter, "ConnectedToCurrentWorksplace", True, DataCompositionComparisonType.Equal,, AllEquipmentCROffline = False);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CurrentSessionWorkplaceChanged" Then
		
		Workplace = EquipmentManagerServerCall.GetClientWorkplace();
		
		Scales.Parameters.SetParameterValue("CurrentWorksPlace", Workplace);
		CashRegisters.Parameters.SetParameterValue("CurrentWorksPlace", Workplace);
		
	ElsIf EventName = "Writing_ExchangeRulesWithPeripheralsOffline"
		OR EventName = "Record_CodesOfGoodsPeripheral" Then
		
		Items.Scales.Refresh();
		Items.CashRegisters.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureCommandHandlers

&AtClient
Procedure ScalesViewProductsList(Command)
	
	CurrentData = Items.Scales.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.ExchangeRule) Then
		
		FormParameters = New Structure("Device, ExchangeRule", CurrentData.Peripherals, CurrentData.ExchangeRule);
		OpenForm("InformationRegister.ProductsCodesPeripheralOffline.Form.ProductsList", FormParameters, UUID);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ScalesSetRuleForSelected(Command)
	
	Device = New Array;
	For Each SelectedRow In Items.Scales.SelectedRows Do
		Device.Add(SelectedRow);
	EndDo;
	
	If Device.Count() > 0 Then
		
		OpenParameters = New Structure;
		OpenParameters.Insert("PeripheralsType", PredefinedValue("Enum.PeripheralTypes.LabelsPrintingScales"));
		Notification = New NotifyDescription("ScalesSetRuleForSelectedCompletion",ThisForm,Device);
		OpenForm("Catalog.ExchangeWithOfflinePeripheralsRules.ChoiceForm", OpenParameters, UUID,,,,Notification);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ScalesSetRuleForSelectedCompletion(ExchangeRule,Device) Export
	
	If ValueIsFilled(ExchangeRule) Then
		AssignRuleForHighlitedDevicesAtServer(Device, ExchangeRule);
	EndIf;
		
	Items.Scales.Refresh();
	
EndProcedure

&AtClient
Procedure ScalesProductsExport(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"ScalesProductsExchangeScalesOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.LabelsPrintingScales"), Items.Scales.SelectedRows,,, NotificationOnImplementation, True);
	
EndProcedure

&AtClient
Procedure ScalesProductsExchangeScalesOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Items.Scales.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure ScalesProductsClear(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"ScalesProductsExchangeScalesOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousClearProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.LabelsPrintingScales"), Items.Scales.SelectedRows,,, NotificationOnImplementation);
	
EndProcedure

&AtClient
Procedure ScalesProductsReload(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"ScalesProductsExchangeScalesOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.LabelsPrintingScales"), Items.Scales.SelectedRows,,, NotificationOnImplementation, False);
	
EndProcedure

&AtClient
Procedure CashesViewProductList(Command)
	
	CurrentData = Items.CashRegisters.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.ExchangeRule) Then
		
		FormParameters = New Structure("Device, ExchangeRule", CurrentData.Peripherals, CurrentData.ExchangeRule);
		OpenForm("InformationRegister.ProductsCodesPeripheralOffline.Form.ProductsList", FormParameters, UUID);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashAccountsSetRuleForSelected(Command)
	
	Device = New Array;
	For Each SelectedRow In Items.CashRegisters.SelectedRows Do
		Device.Add(SelectedRow);
	EndDo;
	
	If Device.Count() > 0 Then
		
		OpenParameters = New Structure;
		OpenParameters.Insert("PeripheralsType", PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline"));
		Notification = New NotifyDescription("CashAccountsSetRuleForSelectedCompletion",ThisForm,Device);
		OpenForm("Catalog.ExchangeWithOfflinePeripheralsRules.ChoiceForm", OpenParameters, UUID,,,,Notification);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashAccountsSetRuleForSelectedCompletion(ExchangeRule,Device) Export
	
	If ValueIsFilled(ExchangeRule) Then
		AssignRuleForHighlitedDevicesAtServer(Device, ExchangeRule);
	EndIf;
		
	Items.CashRegisters.Refresh();
	
EndProcedure

&AtClient
Procedure CashAccountsProductsExport(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"CashAccountsProductsExchangeWithCashRegisterOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline"), Items.CashRegisters.SelectedRows,,, NotificationOnImplementation, True);
	
EndProcedure

&AtClient
Procedure CashAccountsProductsExchangeWithCashRegisterOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Items.CashRegisters.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure CashAccountsProductsClear(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"CashAccountsProductsExchangeWithCashRegisterOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousClearProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline"), Items.CashRegisters.SelectedRows,,, NotificationOnImplementation);
	
EndProcedure

&AtClient
Procedure CashAccountsProductsReload(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"CashAccountsProductsExchangeWithCashRegisterOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline"), Items.CashRegisters.SelectedRows,,, NotificationOnImplementation, False);
	
EndProcedure

&AtClient
Procedure CashAccountsGoodsIImportReportAboutRetailSales(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"CashAccountsProductsExchangeWithCashRegisterOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousImportReportAboutRetailSales(Items.CashRegisters.SelectedRows,,, NotificationOnImplementation);
	
EndProcedure

&AtClient
Procedure ScalesOpenExchangeRule(Command)
	
	CurrentData = Items.Scales.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.ExchangeRule) Then
		
		ShowValue(Undefined,CurrentData.ExchangeRule);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashAccountsOpenExchangeRule(Command)
	
	CurrentData = Items.CashRegisters.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.ExchangeRule) Then
		
		ShowValue(Undefined,CurrentData.ExchangeRule);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AutomaticExchange(Command)
	
	FormParameters = New Structure("Workplace", Workplace);
	OpenForm("CommonForm.ExchangeWithOfflinePeropherals", FormParameters);
	
EndProcedure

#EndRegion

#Region ProcedureFormItemsEventsHandlers

&AtClient
Procedure WarehouseScalesOnChange(Item)
	
	CommonClientServer.SetFilterItem(Scales.Filter, "Warehouse", WarehouseScales, DataCompositionComparisonType.Equal,, ValueIsFilled(WarehouseScales));
	
EndProcedure

&AtClient
Procedure ExchangeRuleScalesOnChange(Item)
	
	CommonClientServer.SetFilterItem(Scales.Filter, "ExchangeRule", ExchangeRuleScales, DataCompositionComparisonType.Equal,, ValueIsFilled(ExchangeRuleScales));
	
EndProcedure

&AtClient
Procedure WarehouseCashRegisterOfflineOnChange(Item)
	
	CommonClientServer.SetFilterItem(CashRegisters.Filter, "Warehouse", WarehouseCROffline, DataCompositionComparisonType.Equal,, ValueIsFilled(WarehouseCROffline));
	
EndProcedure

&AtClient
Procedure ExchangeRuleCashRegisterOfflineOnChange(Item)
	
	CommonClientServer.SetFilterItem(CashRegisters.Filter, "ExchangeRule", CROfflineExchangeRule, DataCompositionComparisonType.Equal,, ValueIsFilled(CROfflineExchangeRule));
	
EndProcedure

&AtClient
Procedure EquipmentCashRegisterOfflineOnChange(Item)
	
	CommonClientServer.SetFilterItem(CashRegisters.Filter, "ConnectedToCurrentWorksplace", True, DataCompositionComparisonType.Equal,, AllEquipmentCROffline = False);
	
EndProcedure

&AtClient
Procedure EquipmentScalesOnChange(Item)
	
	CommonClientServer.SetFilterItem(Scales.Filter, "ConnectedToCurrentWorksplace", True, DataCompositionComparisonType.Equal,, AllEquipmentScales = False);
	
EndProcedure

&AtClient
Procedure CashRegistersChoice(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	
	If Field = Items.CashRegistersImportDate AND ValueIsFilled(CurrentData.ImportDate) Then
		StandardProcessing = False;
		Report = GetReportAboutRetailSalesByPettyCash(CurrentData.CashCR, CurrentData.ImportDate);
		
		If ValueIsFilled(Report) Then
			ShowValue(Undefined,Report);
		Else
			ShowMessageBox(Undefined,NStr("en = 'Shift closure not found.'; ru = 'Отчет о розничных продажах не найден.';pl = 'Zamknięcie zmiany nie znaleziono.';es_ES = 'Cierre del turno no encontrado.';es_CO = 'Cierre del turno no encontrado.';tr = 'Vardiya kapanış raporu bulunamadı.';it = 'Chiusura turno non trovata.';de = 'Abschluss der Schicht nicht gefunden.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AssignRuleForHighlitedDevicesAtServer(Device, ExchangeRule)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	For Each Device In Device Do
		
		DeviceObject = Device.GetObject();
		DeviceObject.ExchangeRule = ExchangeRule;
		DeviceObject.Write();
		
	EndDo;
	
	CommitTransaction();
	
EndProcedure

&AtServer
Function GetReportAboutRetailSalesByPettyCash(CashCR, ImportDate)
	
	Report = Undefined;
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	ShiftClosure.Ref AS Report
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	ShiftClosure.CashCR = &CashCR
	|	AND ShiftClosure.Date between &StartDate AND &EndDate");
	
	Query.SetParameter("CashCR", CashCR);
	Query.SetParameter("StartDate",    ImportDate - 5);
	Query.SetParameter("EndDate", ImportDate + 5);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		Report = Selection.Report;
	EndIf;
	
	Return Report;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ColorAuto	= New Color();
	ColorRed	= WebColors.Red;
	FontCash	= New Font(StyleFonts.FontDialogAndMenu,,,False,,True);
	
	// CashRegisters
	
	ItemAppearance = CashRegisters.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ConnectedToCurrentWorksplace");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorAuto);
	
	ItemAppearance = CashRegisters.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ExchangeRule");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRed);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<Not set>'; ru = '<Не задано>';pl = '<Nieustawione>';es_ES = '<No establecido>';es_CO = '<No establecido>';tr = '<Belirlenmedi>';it = '<Non impostato>';de = '<Nicht festgelegt>'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ExchangeRule");
	FieldAppearance.Use = True;
	
	ItemAppearance = CashRegisters.ConditionalAppearance.Items.Add();
	
	ItemAppearance.Appearance.SetParameterValue("Font", FontCash);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ImportDate");
	FieldAppearance.Use = True;
	
	// Scales
	
	ItemAppearance = Scales.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ConnectedToCurrentWorksplace");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorAuto);
	
	ItemAppearance = Scales.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ExchangeRule");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorRed);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<Not set>'; ru = '<Не задано>';pl = '<Nieustawione>';es_ES = '<No establecido>';es_CO = '<No establecido>';tr = '<Belirlenmedi>';it = '<Non impostato>';de = '<Nicht festgelegt>'"));

EndProcedure

#EndRegion
