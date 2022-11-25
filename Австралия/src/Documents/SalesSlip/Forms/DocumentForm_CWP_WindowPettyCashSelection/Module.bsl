#Region ServiceProceduresAndFunctions

// Fills document Receipt CR by cash register.
//
// Parameters
//  FillingData - Structure with the filter values
//
&AtServer
Procedure FillDocumentByCachRegister(CashCR, ParametersStructure = Undefined)
	
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
	If POSTerminal.IsEmpty() OR CashCR <> POSTerminal.PettyCash Then
		If ParametersStructure = Undefined Then
			Object.POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(Object.CashCR);
			POSTerminal = Object.POSTerminal;
		Else
			Object.POSTerminal = ParametersStructure.POSTerminal;
			POSTerminal = Object.POSTerminal;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	
	If Parameters.Property("ParametersStructure")
		AND Parameters.ParametersStructure.Property("CashCR") Then
		
		ParametersStructure = Parameters.ParametersStructure;
	Else
		ParametersStructure = CashierWorkplaceServerCall.GetDefaultCashRegisterAndTerminal();
	EndIf;
	
	Object.CashCR = ParametersStructure.CashCR;
	If Object.CashCR <> Undefined Then
		FillDocumentByCachRegister(Object.CashCR, ParametersStructure);
	EndIf;
	
	Workplace = EquipmentManagerServerCall.GetClientWorkplace();
	If Not ValueIsFilled(Workplace) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Failed to identify workplace to work with peripherals.'; ru = 'Не обнаружено рабочее место для работы с внешним оборудованием';pl = 'Nie udało się zidentyfikować miejsca pracy do pracy z urządzeniami peryferyjnymi.';es_ES = 'Se ha fallado identificar el lugar de trabajo para trabajar con periféricos.';es_CO = 'Se ha fallado identificar el lugar de trabajo para trabajar con periféricos.';tr = 'Çevre birimleriyle çalışmak için çalışma alanı tanımlanamadı.';it = 'Non riuscito ad identificare un posto di lavoro che lavora con le periferiche.';de = 'Der Arbeitsplatz konnte nicht identifiziert werden, um mit Peripheriegeräten zu arbeiten.'");
		Message.Message();
	EndIf;
		
	CWPSetting = CashierWorkplaceServerCall.GetCWPSetup(Workplace);
	If Object.CashCR.IsEmpty() Then
		If Not ValueIsFilled(CWPSetting) Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'Failed to receive the CWP settings for current workplace.'; ru = 'Не удалось получить настройки РМК для текущего рабочего места';pl = 'Nie można odebrać ustawień MPK dla bieżącego miejsca pracy.';es_ES = 'Se ha fallado recibir los ajustes CWP para el lugar de trabajo actual.';es_CO = 'Se ha fallado recibir los ajustes CWP para el lugar de trabajo actual.';tr = 'Mevcut çalışma alanı için kasiyer çalışma alanı ayarları alınamadı.';it = 'Non riuscito a ricevere le impostazione della cassa  per il posto di lavoro corrente.';de = 'Die CWP-Einstellungen für den aktuellen Arbeitsplatz konnten nicht empfangen werden.'");
			Message.Message();
		Else
			DontShowOnOpenCashdeskChoiceForm = CWPSetting.DontShowOnOpenCashdeskChoiceForm;
		EndIf;
	Else
		If ParametersStructure.POSTerminalQuantity < 2 Then
			DontShowOnOpenCashdeskChoiceForm = True;
		Else
			DontShowOnOpenCashdeskChoiceForm = CWPSetting.DontShowOnOpenCashdeskChoiceForm;
		EndIf;
	EndIf;
	
	CashCR = Object.CashCR;
	POSTerminal = Object.POSTerminal;
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If DontShowOnOpenCashdeskChoiceForm AND Not Object.CashCR.IsEmpty() Then
		OpenWorkplaceOfCashier(Commands.OpenWorkplaceOfCashier);
	EndIf;
	
EndProcedure

// Procedure - event handler OnLoadDataFromSettingsAtServer.
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	CurCashCR = Settings.Get("CashCR");
	If ValueIsFilled(CurCashCR) Then
		CashCR = CurCashCR;
		Object.CashCR = CashCR;
	EndIf;
	
	CurPOSTerminal = Settings.Get("POSTerminal");
	If ValueIsFilled(CurPOSTerminal) Then
		POSTerminal = CurPOSTerminal;
		Object.POSTerminal = POSTerminal;
	EndIf;
	
	FillDocumentByCachRegister(Object.CashCR);
	
EndProcedure

// Procedure - event handler OnSaveDataInSettingsAtServer.
//
&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	If Not CloseFormAfterOpeningCWP Then
		Settings.Clear();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler OpenCashierWorkplace form.
//
&AtClient
Procedure OpenWorkplaceOfCashier(Command)
	
	If Object.CashCR.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = "Select cashier workplace";
		Message.Field = "CashCR";
		Message.Message();
		Return;
	EndIf;
	
	CloseFormAfterOpeningCWP = True;
	
	CWPParameters = New Structure;
	CWPParameters.Insert("Company", Object.Company);
	CWPParameters.Insert("CashCR", Object.CashCR);
	CWPParameters.Insert("StructuralUnit", Object.StructuralUnit);
	CWPParameters.Insert("POSTerminal", Object.POSTerminal);
	
	CashierWorkplaceServerCall.UpdateCashierWorkplaceSettings(CWPSetting, DontShowOnOpenCashdeskChoiceForm);
	OpenForm("Document.SalesSlip.Form.DocumentForm_CWP", CWPParameters);
	Close();
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item CashCR form.
//
&AtClient
Procedure CashCROnChange(Item)
	
	Object.CashCR = CashCR;
	
	FillDocumentByCachRegister(Object.CashCR);
	
EndProcedure

// Procedure - event handler OnChange item POSTerminal form.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	Object.POSTerminal = POSTerminal;
	
EndProcedure

#EndRegion

