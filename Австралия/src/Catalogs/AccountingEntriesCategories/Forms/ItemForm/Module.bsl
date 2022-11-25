#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion