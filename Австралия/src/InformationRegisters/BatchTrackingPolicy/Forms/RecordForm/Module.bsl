#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Record.BatchSettings) Then
		UseExpirationDate = Common.ObjectAttributeValue(Record.BatchSettings, "UseExpirationDate");
		SetDefaultTrackingPolicyChoiceParameters(UseExpirationDate);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BatchSettingsOnChange(Item)
	
	If ValueIsFilled(Record.BatchSettings) Then
		BatchSettingsOnChangeAtServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetDefaultTrackingPolicyChoiceParameters(UseExpirationDate)
	
	If UseExpirationDate Then
		
		Items.Policy.ChoiceParameters = New FixedArray(New Array);
		
	Else
		
		MethodsArray = New Array;
		MethodsArray.Add(Enums.BatchTrackingMethods.Manual);
		MethodsArray.Add(Enums.BatchTrackingMethods.Referential);
		ChoiceParameter = New ChoiceParameter("Filter.TrackingMethod", New FixedArray(MethodsArray));
		ChoiceParametersArray = New Array;
		ChoiceParametersArray.Add(ChoiceParameter);
		Items.Policy.ChoiceParameters = New FixedArray(ChoiceParametersArray);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BatchSettingsOnChangeAtServer()
	
	BatchSettingsData = Common.ObjectAttributesValues(Record.BatchSettings,
		"UseExpirationDate, DefaultTrackingPolicy");
	
	Record.Policy = BatchSettingsData.DefaultTrackingPolicy;
	
	SetDefaultTrackingPolicyChoiceParameters(BatchSettingsData.UseExpirationDate);
	
EndProcedure

#EndRegion