#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Procedure sets the form attribute visible.
//
// Parameters:
//  No.
//
Procedure SetAttributesVisible()
	
	If Object.DepreciationMethod = ProportionallyToProductsVolume Then
		Items.MeasurementUnit.Visible = True;
	Else
		Items.MeasurementUnit.Visible = False;
		Object.MeasurementUnit = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial filling and sets
// form attribute visible.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ProportionallyToProductsVolume = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume;
	
	If Object.DepreciationMethod = ProportionallyToProductsVolume Then
		Items.MeasurementUnit.Visible = True;
	Else
		Items.MeasurementUnit.Visible = False;
		Object.MeasurementUnit = Undefined;
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedFixedAssets" Then
		Object.GLAccount = Parameter.GLAccount;
		Object.DepreciationAccount = Parameter.DepreciationAccount;
		Modified = True;
	EndIf;
	
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
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Event handler procedure OnChange of input field DepreciationMethod.
//
Procedure DepreciationMethodOnChange(Item)
	
	SetAttributesVisible();
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
