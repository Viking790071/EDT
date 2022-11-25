#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NoncheckableAttributeArray = New Array;
	
	If Not Catalogs.FilesAccessGroups.AccessGroupsAreUsed() Then
		NoncheckableAttributeArray.Add("AccessGroup");
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

#EndRegion

#EndIf