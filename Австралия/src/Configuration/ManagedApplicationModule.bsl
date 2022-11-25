// StandardSubsystems

#Region Variables

// StandardSubsystems.BaseFunctionality
//  
// Flag that shows whether the file system installation must be suggested in the current session.
Var SuggestFileSystemExtensionInstallation Export;
// ApplicationParameters - Map - variable storage where:
//   * Key - String - variable name in the format as LibraryName.VariableName;
//   * Value - Arbitrary - variable value.
//  
// Initialization (based on EventLogMonitorMessages example):
//   ParameterName = "StandardSubsystems.EventLogMonitorMessages";
//   If ApplicationParameters[ParameterName] =
//     Undefined Then ApplicationParameters.Insert(ParameterName, New ValueList);
//   EndIf;
//  
// Usage (based on EventLogMonitorMessages example):
//   ApplicationParameters["StandardSubsystems.EventLogMonitorMessages"].Add(...);
//   ApplicationParameters["StandardSubsystems.EventLogMonitorMessages"] = ...;
Var ApplicationParameters Export;
// End StandardSubsystems

// StandardSubsystems.Peripherals
Var glPeripherals Export; // for caching on the client
Var glAvailableEquipmentTypes Export;
// End of StandardSubsystems.Peripherals

// ElectronicInteraction
Var ExchangeWithBanksSubsystemsParameters Export;
// For the relevant DS certificate settings the ElectronicSignature-Password pairs will be stored accordingly (in this session)
Var CertificateAndPasswordMatching Export;
// End of ElectronicInteraction

// ServiceTechnology
Var AlertOnRequestForExternalResourcesUseSaaS Export;
// End ServiceTechnology

#EndRegion

#Region EventsHandlers

Procedure BeforeStart()
	
	// StandardSubsystems
	StandardSubsystemsClient.BeforeStart();
	// End StandardSubsystems
	
EndProcedure

Procedure OnStart()
	
	// StandardSubsystems
	StandardSubsystemsClient.OnStart();
	// End StandardSubsystems
	
	// StandardSubsystems.Peripherals
	EquipmentManagerClient.OnStart();
	// End of StandardSubsystems.Peripherals
	
	// begin Drive.FullVersion
	#If MobileClient Then
		
		OpenProductionTaskOnOpen = DriveReUse.GetValueOfSetting("OpenProductionTaskOnOpen");
		If OpenProductionTaskOnOpen Then
			OpenForm("Document.ProductionTask.Form.ListForm", , , , , , , FormWindowOpeningMode.Independent);
		EndIf;
		
	#EndIf
	// end Drive.FullVersion 
	
	If DriveServer.AreUserAndSystemLanguagesDifferent() Then
		OpenForm("CommonForm.DisplayLanguageCheck",,,,,,,FormWindowOpeningMode.LockWholeInterface);
	EndIf;
	
	DriveServer.AttachAddInServer();
	
	If UsersClientServer.IsExternalUserSession() Then
		GlobalPlan = GlobalSearch.GetPlan();
		GlobalPlan.Clear();
		GlobalSearch.SetPlan(GlobalPlan);
	EndIf;
	
EndProcedure

Procedure BeforeExit(Cancel, WarningText)
	
	// StandardSubsystems
	StandardSubsystemsClient.BeforeExit(Cancel, WarningText);
	// End StandardSubsystems
	
	// StandardSubsystems.Peripherals
	EquipmentManagerClient.BeforeExit();
	// End of StandardSubsystems.Peripherals

EndProcedure

// StandardSubsystems.Peripherals
Procedure ExternEventProcessing(Source, Event, Data)
	
	// Prepare data
	DetailsEvents = New Structure();
	ErrorDescription  = "";
	
	If UPPER(Event) = "ШТРИХКОД" Then
		Event = "Barcode";
	EndIf;
		
	DetailsEvents.Insert("Source", Source);
	DetailsEvents.Insert("Event",  Event);
	DetailsEvents.Insert("Data",   Data);

	// Transfer data for processing
	Result = EquipmentManagerClient.ProcessEventFromDevice(DetailsEvents, ErrorDescription);
	If Not Result Then
		CommonClientServer.MessageToUser(NStr("en = 'An error occurred when processing an external event from the device.'; ru = 'При обработке внешнего события от устройства произошла ошибка.';pl = 'W trakcie przetwarzania wydarzenia zewnętrznego z urządzenia wystąpił błąd.';es_ES = 'Ha ocurrido un error al procesar un evento externo del dispositivo.';es_CO = 'Ha ocurrido un error al procesar un evento externo del dispositivo.';tr = 'Harici olayın cihazdan işlenmesi sırasında bir hata oluştu:';it = 'Si è verificato un errore durante l''elaborazione di un evento esterno dal dispositivo.';de = 'Bei der Verarbeitung eines externen Ereignisses vom Gerät ist ein Fehler aufgetreten.'")
															+ Chars.LF + ErrorDescription);
	EndIf;
	
EndProcedure
// End of StandardSubsystems.Peripherals

#EndRegion