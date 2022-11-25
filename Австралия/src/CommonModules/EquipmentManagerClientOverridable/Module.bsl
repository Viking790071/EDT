
#Region ProgramInterface

// Returns the current date adjusted to the time zone of the session.
// It is intended to use instead of the function CurrentDate().
//
Function SessionDate() Export
	
	Return CommonClient.SessionDate();
	
EndFunction

// Function returns the driver handler object by its description.
//
Function GetDriverHandler(DriverHandler, ImportedDriver) Export
	
	Result = PeripheralsUniversalDriverClient;
	
	If Not ImportedDriver AND DriverHandler <> Undefined Then
		
		// Bar code scanners
		
		// End Barcode scanners
		
		// Magnetic card readers
		
		// End Mangnetic cards readers.

		// Customer displays
		
		// End Customners displays
		
		// Data collection terminals
		
		// End Data collection terminals.
		
		// POS terminals
		
		// End POS-Terminals.
		 
		// Electronic scales
		
		// End Electronic scales
		
		// Labels printing scales
		
		// End  Scales with label.
		
		// CR offline
		
		// End CR offline
		
	EndIf;

	Return Result;
	
EndFunction

// Prints a fiscal receipt.
//
Function ReceiptPrint(EquipmentCommonModule, DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters, OutputMessageToUser = False) Export
	
	ProductsTable = InputParameters[0];
	PaymentsTable        = InputParameters[1];
	CommonParameters      = InputParameters[2];
		                 
	Result  = True;
	// Open receipt
	Result = EquipmentCommonModule.OpenReceipt(DriverObject, Parameters, ConnectionParameters,
	                       CommonParameters[0] = 1, CommonParameters[1], Output_Parameters);

	// Print receipt rows   
	If Result Then
		ErrorOnLinePrinting = False;
		// Print receipt rows
		For ArrayIndex = 0 To ProductsTable.Count() - 1 Do
			Description  = ProductsTable[ArrayIndex][0].Value;
			Quantity    = ProductsTable[ArrayIndex][5].Value;
			Price          = ProductsTable[ArrayIndex][4].Value;
			DiscountPercent = ProductsTable[ArrayIndex][8].Value;
			Amount         = ProductsTable[ArrayIndex][9].Value;
			SectionNumber   = ProductsTable[ArrayIndex][3].Value;
			VATRate     = ProductsTable[ArrayIndex][12].Value;

			If Not EquipmentCommonModule.PrintFiscalLine(DriverObject, Parameters, ConnectionParameters,
											   Description, Quantity, Price, DiscountPercent, Amount,
											   SectionNumber, VATRate, Output_Parameters) Then
				ErrorOnLinePrinting = True;   
				Break;
			EndIf;
			
		EndDo;

		If Not ErrorOnLinePrinting Then
		  	// Close receipt
			Result = EquipmentCommonModule.CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);	
		Else
			Result = False;
		EndIf;
		
	EndIf;

	Return Result;
	
EndFunction

#EndRegion

#Region WorkWithFormInstanceEquipment

// Additional overridable actions with handled form
// in the Equipment instance on "OnOpen" event.
//
Procedure EquipmentInstanceOnOpen(Object, ThisForm, Cancel) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "BeforeClose" event.
//
Procedure EquipmentInstanceBeforeClose(Object, ThisForm, Cancel, StandardProcessing) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "BeforeWrite" event.
//
Procedure EquipmentInstanceBeforeWrite(Object, ThisForm, Cancel, WriteParameters) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "AfterWrite" event.
//
Procedure EquipmentInstanceAfterWrite(Object, ThisForm, WriteParameters) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "EquipmentTypeChoiceProcessing" event.
//
Procedure EquipmentInstanceEquipmentTypeSelection(Object, ThisForm, ThisObject, Item, ValueSelected) Export
	
EndProcedure

#EndRegion

#Region EquipmentConnectionDisconnectionProcedures

// Start enabling required devices types during form opening
//
// Parameters:
// Form - ClientApplicationForm
// SupportedPeripheralTypes - String
// 	Contains peripherals types list separated by commas.
//
Procedure StartConnectingEquipmentOnFormOpen(Form, SupportedPeripheralTypes) Export
	
	AlertOnConnect = New NotifyDescription("ConnectEquipmentEnd", EquipmentManagerClientOverridable);
	EquipmentManagerClient.StartConnectingEquipmentOnFormOpen(AlertOnConnect, Form, SupportedPeripheralTypes);
	
EndProcedure

Procedure ConnectEquipmentEnd(ExecutionResult, Parameters) Export
	
	If Not ExecutionResult.Result Then
		MessageText = NStr("en = 'An error occurred when connecting the equipment:""%ErrorDetails%"".'; ru = 'При подключении оборудования произошла ошибка:""%ErrorDetails%"".';pl = 'Wystąpił błąd podczas odłączania urządzenia: ""%ErrorDetails%"".';es_ES = 'Ha ocurrido un error al conectar el equipamiento:""%ErrorDetails%"".';es_CO = 'Ha ocurrido un error al conectar el equipamiento:""%ErrorDetails%"".';tr = 'Ekipman bağlanırken bir hata oluştu: ""%ErrorDetails%"".';it = 'Si è verificato un errore durante il collegamento dell''apparecchiatura: ""%ErrorDetails%"".';de = 'Beim Anschließen des Geräts ist ein Fehler aufgetreten: ""%ErrorDetails%"".'");
		MessageText = StrReplace(MessageText, "%ErrorDetails%" , ExecutionResult.ErrorDetails);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start disconnecting peripherals by type on closing the form.
//
Procedure StartDisablingEquipmentOnCloseForm(Form) Export
	
	AlertOnDisconnect = New NotifyDescription("DisableEquipmentEnd", EquipmentManagerClientOverridable); 
	EquipmentManagerClient.StartDisablingEquipmentOnCloseForm(AlertOnDisconnect, Form);
	
EndProcedure

Procedure DisableEquipmentEnd(ExecutionResult, Parameters) Export
	
	If Not ExecutionResult.Result Then
		MessageText = NStr("en = 'An error occurred when disconnecting the equipment: ""%ErrorDescription%"".'; ru = 'При отключении оборудования произошла ошибка: ""%ErrorDescription%"".';pl = 'Wystąpił błąd podczas odłączania urządzenia: ""%ErrorDescription%"".';es_ES = 'Ha ocurrido un error al desconectar el equipamiento: ""%ErrorDescription%"".';es_CO = 'Ha ocurrido un error al desconectar el equipamiento: ""%ErrorDescription%"".';tr = 'Ekipman devre dışı bırakılırken bir hata oluştu: ""%ErrorDescription%"".';it = 'Si è verificato un errore durante lo spegnimento dell''apparecchiatura: ""%ErrorDescription%"".';de = 'Beim Trennen des Geräts ist ein Fehler aufgetreten: ""%ErrorDescription%"".'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%" , ExecutionResult.ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion
