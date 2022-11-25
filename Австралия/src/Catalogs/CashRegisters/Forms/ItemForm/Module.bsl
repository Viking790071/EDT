
#Region GeneralPurposeProceduresAndFunctions

// Function generates a bank account description.
//
&AtClient
Function MakeAutoDescription()
	
	Items.Description.ChoiceList.Clear();
	
	DescriptionString = "" + Object.CashCRType + " (" + Object.StructuralUnit + ")";
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	Return DescriptionString;

EndFunction

// Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not Parameters.FillingValues.Property("Owner")
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Object.Owner = SettingValue;
		Else
			Object.Owner = Catalogs.Companies.MainCompany;
		EndIf;
		If Not Constants.UsePeripherals.Get() Then
			Object.UseWithoutEquipmentConnection = True;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		Object.CashCurrency = DriveReUse.GetFunctionalCurrency();
	EndIf;
	
	CashCRTypeOnChangeAtServer();
	
	If Object.UseWithoutEquipmentConnection
	AND Not Constants.UsePeripherals.Get() Then
		Items.UseWithoutEquipmentConnection.Enabled = False;
	EndIf;
	
	Items.Peripherals.Enabled = Not Object.UseWithoutEquipmentConnection;
	
	If GetFunctionalOption("UseOfflineExchangeWithPeripherals") Then
		Items.CashCRType.ChoiceList.Add(Enums.CashRegisterTypes.CashRegistersOffline);
	EndIf;
	
	Items.Owner.Visible = GetFunctionalOption("UseSeveralCompanies");
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
		
EndProcedure

// Procedure - form event handler "AfterWriteAtServer".
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure CashCRTypeOnChangeAtServer()
	
	If Object.CashCRType = Enums.CashRegisterTypes.FiscalRegister Then
		
		Items.UseWithoutEquipmentConnection.Visible = True;
		Items.Peripherals.Visible = True;
		
		VarChoiceParameters = New Array;
		VarChoiceParameters .Add(New ChoiceParameter("Filter.EquipmentType", Enums.PeripheralTypes.FiscalRegister));
		VarChoiceParameters.Add(New ChoiceParameter("Filter.DeviceIsInUse", True));
		VarChoiceParameters.Add(New ChoiceParameter("Filter.DeletionMark", False));
		
		Items.Peripherals.ChoiceParameters = New FixedArray(VarChoiceParameters);
		
		If Object.Peripherals.EquipmentType <> Enums.PeripheralTypes.FiscalRegister Then
			Object.Peripherals = Undefined;
		EndIf;
		
	ElsIf Object.CashCRType = Enums.CashRegisterTypes.CashRegistersOffline Then
		
		Items.UseWithoutEquipmentConnection.Visible = False;
		Items.Peripherals.Visible = True;
		
		VarChoiceParameters = New Array;
		VarChoiceParameters.Add(New ChoiceParameter("Filter.EquipmentType", Enums.PeripheralTypes.CashRegistersOffline));
		VarChoiceParameters.Add(New ChoiceParameter("Filter.DeviceIsInUse", True));
		VarChoiceParameters.Add(New ChoiceParameter("Filter.DeletionMark", False));
		
		Items.Peripherals.ChoiceParameters = New FixedArray(VarChoiceParameters);
		
		If Object.Peripherals.EquipmentType <> Enums.PeripheralTypes.CashRegistersOffline Then
			Object.Peripherals = Undefined;
		EndIf;
		
	Else
		
		Items.UseWithoutEquipmentConnection.Visible = False;
		Items.Peripherals.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashCRTypeOnChange(Item)
	
	CashCRTypeOnChangeAtServer();
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure PeripheralsOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.Peripherals.ObjectForm", New Structure("Key", Object.Peripherals));
	
EndProcedure

&AtClient
Procedure UseWithoutEquipmentConnectionOnChange(Item)
	
	Items.Peripherals.Enabled = Not Object.UseWithoutEquipmentConnection;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CashRegisterAccountsChanged" Then
		Object.GLAccount = Parameter.GLAccount;
		Modified = True;
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
