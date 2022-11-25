
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisObject, ExternalUsers.ExternalUserAuthorizationData());
	CommonClientServer.SetDynamicListFilterItem(List, "Owner", AuthorizedCounterparty, DataCompositionComparisonType.Equal);
	CommonClientServer.SetDynamicListFilterItem(List, "DeletionMark", False, DataCompositionComparisonType.Equal);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
