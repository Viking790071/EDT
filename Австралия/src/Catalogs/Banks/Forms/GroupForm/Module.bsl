
&AtServer
Procedure FillFormByObject()
	
	BankOperationsDrive.ReadManualEditFlag(ThisForm);
	
EndProcedure

#Region ProcedureFormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		
		FillFormByObject();
		
		AutoTitle = False;
		
		Title = NStr("en = 'Banks (Create group)'; ru = 'Банки (создать группу)';pl = 'Banki (Utwórz grupę)';es_ES = 'Bancos (Crear un grupo)';es_CO = 'Bancos (Crear un grupo)';tr = 'Bankalar (Grup oluştur)';it = 'Banche (Crea gruppo)';de = 'Banken (Gruppe erstellen)'");
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillFormByObject();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.ManualChanging = ?(ManualChanging = Undefined, 2, ManualChanging);
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If Not AutoTitle Then
	
		AutoTitle = True;
		
		Title = "";
	
	EndIf; 
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	Text = NStr("en = 'The data is updated automatically.
	            |After the manual change this item will not be updated automatically.
	            |Do you want to continue?'; 
	            |ru = 'Данные обновляются автоматически.
	            |После ручного изменения автоматическое обновление этого элемента производиться не будет.
	            |Продолжить изменение?';
	            |pl = 'Dane są automatycznie aktualizowane.
	            |Po ręcznej zmianie ta pozycja nie będzie aktualizowana automatycznie.
	            |Czy chcesz kontynuować?';
	            |es_ES = 'Los datos se han actualizado automáticamente.
	            |Después del cambio manual, este artículo no se actualizará automáticamente.
	            |¿Quiere continuar?';
	            |es_CO = 'Los datos se han actualizado automáticamente.
	            |Después del cambio manual, este artículo no se actualizará automáticamente.
	            |¿Quiere continuar?';
	            |tr = 'Veri otomatik olarak güncellendi. 
	            |Manuel değişiklikten sonra bu öğe otomatik olarak güncellenmez. 
	            |Devam etmek istiyor musunuz?';
	            |it = 'I dati vengono aggiornati automaticamente.
	            |Dopo che la modifica manuale questo elemento non verrà aggiornato automaticamente.
	            |Continuare?';
	            |de = 'Die Daten werden automatisch aktualisiert.
	            |Nach der manuellen Änderung wird dieser Artikel nicht automatisch aktualisiert.
	            |Möchten Sie fortsetzen?'");
	Result = Undefined;

	ShowQueryBox(New NotifyDescription("ChangeEnd", ThisObject), Text, QuestionDialogMode.YesNo,, DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure ChangeEnd(Result1, AdditionalParameters) Export
    
    Result = Result1;
    
    If Result = DialogReturnCode.Yes Then
        
        LockFormDataForEdit();
        Modified = True;
        ManualChanging    = True;
		
        BankOperationsClientDrive.ProcessManualEditFlag(ThisForm);
        
    EndIf;

EndProcedure

&AtClient
Procedure UpdateFromClassifier(Command)
	
	ExecuteUpdate = False;
	BankOperationsClientDrive.RefreshItemFromClassifier(ThisForm, ExecuteUpdate);
	
EndProcedure

&AtServer
Procedure UpdateAtServer()
	
	BankOperationsDrive.RestoreItemFromSharedData(ThisForm);
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of response on the question about data update from classifier
//
Procedure DetermineNecessityForDataUpdateFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		LockFormDataForEdit();
		Modified = True;
		UpdateAtServer();
		NotifyChanged(Object.Ref);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
