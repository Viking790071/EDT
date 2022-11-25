
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.ChangeListQueryTextForCurrentLanguage(ThisObject);
	
EndProcedure

#EndRegion
