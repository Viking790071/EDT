#Region Private

Procedure AllowObjectAttributeEditAfterWarning(ContinuationHandler) Export
	
	If ContinuationHandler <> Undefined Then
		ExecuteNotifyProcessing(ContinuationHandler, False);
	EndIf;
	
EndProcedure

Procedure AllowObjectAttributeEditAfterCheckRefs(Result, Parameters) Export
	
	If Result Then
		ObjectAttributesLockClient.SetAttributeEditEnabling(
			Parameters.Form, Parameters.LockedAttributes);
		
		ObjectAttributesLockClient.SetFormItemEnabled(Parameters.Form);
	EndIf;
	
	If Parameters.ContinuationHandler <> Undefined Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, Result);
	EndIf;
	
EndProcedure

Procedure CheckObjectReferenceAfterValidationConfirm(Response, Parameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, False);
		Return;
	EndIf;
		
	If Parameters.RefsArray.Count() = 0 Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, True);
		Return;
	EndIf;
	
	If CommonServerCall.RefsToObjectFound(Parameters.RefsArray) Then
		
		If Parameters.RefsArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Элемент ""%1"" уже используется в других местах в программе.
				           |Не рекомендуется разрешать редактирование из-за риска рассогласования данных.'; 
				           |en = 'Item ""%1"" is already used in other parts of the application.
				           |It is not recommended that you allow editing due to risk of data inconsistency.'; 
				           |pl = 'Element ""%1"" jest już używany w innych miejscach aplikacji.
				           |Nie zaleca się zezwalania na edycję ze względu na ryzyko niezgodności danych.';
				           |es_ES = 'El artículo ""%1"" ya está utilizado en otras ubicaciones en la aplicación.
				           |No se recomienda permitir la edición debido al riesgo del desajuste de datos.';
				           |es_CO = 'El artículo ""%1"" ya está utilizado en otras ubicaciones en la aplicación.
				           |No se recomienda permitir la edición debido al riesgo del desajuste de datos.';
				           |tr = '""%1"" Öğesi, uygulamadaki diğer yerlerde zaten kullanılıyor. 
				           |Veri yanlış hizalama riskinden dolayı düzenlemeye izin verilmemesi önerilir.';
				           |it = 'L''elemento ""%1"" è già utilizzato in altre parte dell''applicazione. 
				           |Non è raccomandato di permettere la modifica per il rischio di inconsistenza dati.';
				           |de = 'Element ""%1"" wird bereits an anderen Stellen in der Anwendung verwendet.
				           |Es wird nicht empfohlen, die Bearbeitung aufgrund des Risikos von Datenverlagerungen zuzulassen.'"),
				Parameters.RefsArray[0]);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Выбранные элементы (%1) уже используются в других местах в программе.
				           |Не рекомендуется разрешать редактирование из-за риска рассогласования данных.'; 
				           |en = 'The selected items (%1) are already used in other parts of the application.
				           |It is not recommended that you allow editing due to risk of data inconsistency.'; 
				           |pl = 'Wybrane elementy (%1) są już używane w innych miejscach aplikacji. 
				           |Nie zaleca się zezwalania na edycję ze względu na ryzyko niezgodności danych.';
				           |es_ES = 'Artículos seleccionados (%1) ya se utilizan en otras ubicaciones en la aplicación.
				           |No se recomienda permitir la edición debido al riesgo del desajuste de datos.';
				           |es_CO = 'Artículos seleccionados (%1) ya se utilizan en otras ubicaciones en la aplicación.
				           |No se recomienda permitir la edición debido al riesgo del desajuste de datos.';
				           |tr = 'Seçilmiş öğeler (%1), uygulamadaki diğer yerlerde zaten kullanılıyor. 
				           |nVeri yanlış hizalama riskinden dolayı düzenlemeye izin verilmemesi önerilir.';
				           |it = 'Gli elementi selezionati (%1) sono già utilizzati in altre parti dell''applicazione. 
				           |Non è raccomando di permettere la modifica per il rischio di inconsistenza dati.';
				           |de = 'Ausgewählte Elemente (%1) werden bereits an anderen Stellen in der Anwendung verwendet.
				           |Es wird nicht empfohlen, die Bearbeitung aufgrund des Risikos von Datenverlagerungen zuzulassen.'"),
				Parameters.RefsArray.Count());
		EndIf;
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("ru = 'Разрешить редактирование'; en = 'Allow editing'; pl = 'Udostępnij edycję';es_ES = 'Activar la edición';es_CO = 'Activar la edición';tr = 'Düzenlemeye izin ver';it = 'Consentire la modifica';de = 'Bearbeitung aktivieren'"));
		Buttons.Add(DialogReturnCode.No, NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
		ShowQueryBox(
			New NotifyDescription(
				"CheckObjectRefsAfterEditConfirmation", ThisObject, Parameters),
			MessageText, Buttons, , DialogReturnCode.No, Parameters.DialogTitle);
	Else
		If Parameters.RefsArray.Count() = 1 Then
			ShowUserNotification(NStr("ru = 'Редактирование реквизитов разрешено'; en = 'Attribute editing allowed'; pl = 'Edycja atrybutów jest dozwolona';es_ES = 'Edición del atributo está permitida';es_CO = 'Edición del atributo está permitida';tr = 'Öznitelik düzenlemeye izin verilir';it = 'Modifica attributi concessa';de = 'Attributbearbeitung ist erlaubt'"),
				GetURL(Parameters.RefsArray[0]), Parameters.RefsArray[0]);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Разрешено редактирование реквизитов объектов (%1)'; en = 'Attribute editing allowed for objects (%1)'; pl = 'Edytowanie atrybutów obiektu jest dozwolone (%1)';es_ES = 'Edición de los atributos del objeto está permitida (%1)';es_CO = 'Edición de los atributos del objeto está permitida (%1)';tr = 'Nesne özelliklerinin düzenlenmesine izin verilir (%1)';it = 'Modifica attributi concessa per gli oggetti (%1)';de = 'Bearbeiten von Objektattributen ist erlaubt (%1)'"),
				Parameters.RefsArray.Count());
			
			ShowUserNotification(NStr("ru = 'Редактирование реквизитов разрешено'; en = 'Attribute editing allowed'; pl = 'Edycja atrybutów jest dozwolona';es_ES = 'Edición del atributo está permitida';es_CO = 'Edición del atributo está permitida';tr = 'Öznitelik düzenlemeye izin verilir';it = 'Modifica attributi concessa';de = 'Attributbearbeitung ist erlaubt'"),,
				MessageText);
		EndIf;
		ExecuteNotifyProcessing(Parameters.ContinuationHandler, True);
	EndIf;
	
EndProcedure

Procedure CheckObjectRefsAfterEditConfirmation(Response, Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler, Response = DialogReturnCode.Yes);
	
EndProcedure

#EndRegion
