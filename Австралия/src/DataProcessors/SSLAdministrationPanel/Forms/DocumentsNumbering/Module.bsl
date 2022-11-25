
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange of field UseCustomizableNumbering.
//
&AtClient
Procedure FunctionalOptionUseCustomizableNumberingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogNumerators(Command)
	
	EquipmentManagerClient.RefreshClientWorkplace();
	OpenForm("Catalog.Numerators.ListForm");
	
EndProcedure

// Procedure - command handler Workplaces.
//
&AtClient
Procedure OpenNumberingIndexes(Command)
	
	OpenForm("InformationRegister.NumberingIndexes.ListForm", , ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure controls the group visible WEB Application
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UseCustomizableNumbering" OR AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "SettingsName", "Enabled", ConstantsSet.UseCustomizableNumbering);
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If StrFind(AttributePathToData, "ConstantsSet.") = 1 Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = StrReplace(AttributePathToData, "ConstantsSet.", "");
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure;
		NotificationForms.Insert("EventName", "Record_ConstantsSet");
		NotificationForms.Insert("Parameter", New Structure("Value", ConstantValue));
		NotificationForms.Insert("Source", ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

#EndRegion
