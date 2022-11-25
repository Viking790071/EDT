
#Region Private

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandExecuteParameters.Source.FormName = "Catalog.Products.Form.ItemForm" 
		And CommandExecuteParameters.Source.Modified Then
		
		QuestionText = NStr("en = 'There are unsaved changes in the product details. 
			|They will be saved automatically. 
			|Do you want to continue?'; 
			|ru = 'Данные номенклатуры были изменены
			|Изменения сохранятся автоматически.
			|Продолжить?';
			|pl = 'Istnieją niezapisane zmiany w szczegółach produktu. 
			|Zostaną one zapisane automatycznie. 
			|Czy chcesz kontynuować?';
			|es_ES = 'Hay cambios sin guardar en los detalles del producto. 
			|Se guardarán automáticamente
			|¿Quiere continuar?';
			|es_CO = 'Hay cambios sin guardar en los detalles del producto. 
			|Se guardarán automáticamente
			|¿Quiere continuar?';
			|tr = 'Ürün ayrıntılarında kaydedilmemiş değişiklikler var.
			|Değişiklikler otomatik olarak kaydedilecek.
			|Devam etmek istiyor musunuz?';
			|it = 'Ci sono modifiche non salvate nei dettagli dell''articolo. 
			|Saranno salvate automaticamente. 
			|Continuare?';
			|de = 'Es gibt ungespeicherte Änderungen in den Produktdetails. 
			|Sie werden automatisch gespeichert. 
			|Möchten Sie fortfahren?'");
		
		AdditionalParameters = New Structure("CommandParameter, CommandExecuteParameters",
			CommandParameter, 
			CommandExecuteParameters);
		
		ShowQueryBox(New NotifyDescription("CommandProcessingFragment", ThisObject, AdditionalParameters), 
			QuestionText, 
			QuestionDialogMode.YesNo);
		
	Else 
		
		CommandProcessingEnd(CommandParameter, CommandExecuteParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommandProcessingFragment(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	CommandParameter			= AdditionalParameters.CommandParameter;
	CommandExecuteParameters	= AdditionalParameters.CommandExecuteParameters;
	
	Try
	
		CommandExecuteParameters.Source.Write();
	
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred while saving the product card: %1.'; ru = 'Ошибка сохранения карточки номенклатуры: %1.';pl = 'Wystąpił błąd podczas zapisywania karty produktu: %1.';es_ES = 'Ha ocurrido un error al guardar la tarjeta del producto: %1.';es_CO = 'Ha ocurrido un error al guardar la tarjeta del producto: %1.';tr = 'Ürün kartı kaydedilirken hata oluştu: %1.';it = 'Si è verificato un errore durante il salvataggio della scheda articolo: %1.';de = 'Beim Speichern der Produktkarte ist ein Fehler aufgetreten: %1.'"),
			BriefErrorDescription(ErrorInfo()));
		CommonClientServer.MessageToUser(ErrorDescription);
		Return;
	
	EndTry;
	
	CommandProcessingEnd(CommandParameter, CommandExecuteParameters);

EndProcedure

&AtClient
Procedure CommandProcessingEnd(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("Products", CommandParameter);
	FormParameters = New Structure("Filter", FilterStructure);
	
	OpenForm("Catalog.SuppliersProducts.ListForm",
				FormParameters,
				CommandExecuteParameters.Source,
				CommandExecuteParameters.Uniqueness,
				CommandExecuteParameters.Window,
				CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion