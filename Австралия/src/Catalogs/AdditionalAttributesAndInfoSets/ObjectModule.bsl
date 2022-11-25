#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT IsFolder Then
		
		// Deleting duplicates and empty rows.
		SelectedProperties = New Map;
		PropertiesToDelete = New Array;
		
		// Additional attributes.
		For each AdditionalAttribute In AdditionalAttributes Do
			
			If AdditionalAttribute.Property.IsEmpty()
			 OR SelectedProperties.Get(AdditionalAttribute.Property) <> Undefined Then
				
				PropertiesToDelete.Add(AdditionalAttribute);
			Else
				SelectedProperties.Insert(AdditionalAttribute.Property, True);
			EndIf;
		EndDo;
		
		For each PropertyToDelete In PropertiesToDelete Do
			AdditionalAttributes.Delete(PropertyToDelete);
		EndDo;
		
		SelectedProperties.Clear();
		PropertiesToDelete.Clear();
		
		// Additional info.
		For each AdditionalInfoItem In AdditionalInfo Do
			
			If AdditionalInfoItem.Property.IsEmpty()
			 OR SelectedProperties.Get(AdditionalInfoItem.Property) <> Undefined Then
				
				PropertiesToDelete.Add(AdditionalInfoItem);
			Else
				SelectedProperties.Insert(AdditionalInfoItem.Property, True);
			EndIf;
		EndDo;
		
		For each PropertyToDelete In PropertiesToDelete Do
			AdditionalInfo.Delete(PropertyToDelete);
		EndDo;
		
		// Calculating the number of properties not marked for deletion.
		AttributesNumber = Format(AdditionalAttributes.FindRows(
			New Structure("DeletionMark", False)).Count(), "NG=");
		
		InfoCount   = Format(AdditionalInfo.FindRows(
			New Structure("DeletionMark", False)).Count(), "NG=");
	
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT IsFolder Then
		// Updates content of the top group to use fields of the dynamic list and its settings (filters, ...
		// ) upon customization.
		If ValueIsFilled(Parent) Then
			PropertyManagerInternal.CheckRefreshGroupPropertiesContent(Parent);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
