#Region ProgramInterface

Procedure AfterWriteTaxInvoice(Form, FormOwner, Object) Export
	
	BasisDocumentsArray = Object.BasisDocuments.FindRows(New Structure());
	
	// If you open this form from the document form, then you should change the text there
	If Not FormOwner = Undefined Then
		If TypeOf(FormOwner) = Type("ClientApplicationForm") Then
			Form.CloseOnChoice = False;
			
			If Find(FormOwner.FormName, "DocumentForm") <> 0 Then
				BasisDocument = Object.BasisDocuments.FindRows(New Structure("BasisDocument", FormOwner.Object.Ref));
				
				If ValueIsFilled(BasisDocument)
					OR FormOwner.Object.Ref = BasisDocument Then
						If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment")
							Or Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceReceived.AdvancePayment") Then
							Presentation = WorkWithVATClientServer.AdvancePaymentInvoicePresentation(Object.Date, Object.Number);
						Else
							Presentation = WorkWithVATClientServer.TaxInvoicePresentation(Object.Date, Object.Number);
						EndIf;
						Form.NotifyChoice(Presentation);
				EndIf;
			Else
				If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment")
					Or Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceReceived.AdvancePayment") Then
					Presentation = WorkWithVATClientServer.AdvancePaymentInvoicePresentation(Object.Date, Object.Number);
				Else
					Presentation = WorkWithVATClientServer.TaxInvoicePresentation(Object.Date, Object.Number);
				EndIf;
				
				Structure = New Structure;
				Structure.Insert("BasisDocuments",	BasisDocumentsArray);
				Structure.Insert("Presentation",	Presentation);
				
				Notify("RefreshTaxInvoiceText", Structure);
			EndIf; 
		EndIf;
	Else
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceReceived.AdvancePayment") Then
			Presentation = WorkWithVATClientServer.AdvancePaymentInvoicePresentation(Object.Date, Object.Number);
		Else
			Presentation = WorkWithVATClientServer.TaxInvoicePresentation(Object.Date, Object.Number);
		EndIf;
		
		Structure = New Structure;
		Structure.Insert("BasisDocuments",	BasisDocumentsArray);
		Structure.Insert("Presentation",	Presentation);
		
		Notify("RefreshTaxInvoiceText", Structure);
	EndIf;
	
EndProcedure

Procedure OpenTaxInvoice(DocumentForm, Received = False, Advance = False) Export
	
	InvoiceFound = WorkWithVATServerCall.GetSubordinateTaxInvoice(DocumentForm.Object.Ref, Received, Advance);
	
	If DocumentForm.Object.DeletionMark 
		AND Not ValueIsFilled(InvoiceFound) Then
		MessageText = NStr("en = 'Please select a base document that is not marked for deletion.'; ru = '????????????-?????????????? ???????????? ?????????????? ???? ?????????????????? ??????????????????, ?????????????????????? ???? ????????????????.';pl = 'Wybierz dokument ??r??d??owy niezaznaczony do usuni??cia.';es_ES = 'Por favor, seleccionar un documento de base que no est?? marcado para borrar.';es_CO = 'Por favor, seleccionar un documento de base que no est?? marcado para borrar.';tr = 'L??tfen, silinmek ??zere i??aretlenmemi?? bir temel belge se??in.';it = 'Si prega di selezionare un documento di base che non ?? contrassegnato per l''eliminazione.';de = 'Bitte w??hlen Sie ein Basisdokument aus, das nicht zum L??schen markiert ist.'");	
		CommonClientServer.MessageToUser(MessageText);
		
		Return;	
	EndIf;
	
	If DocumentForm.Modified Then
		MessageText = NStr("en = 'Please save the document.'; ru = '???????????????? ?????? ??????????????. ?????????????? ?????????????? ???????????????? ????????????????.';pl = 'Dokument zosta?? zmieniony. Najpierw nale??y zapisa?? dokument.';es_ES = 'Por favor, guardar el documento.';es_CO = 'Por favor, guardar el documento.';tr = 'L??tfen, belgeyi kaydedin.';it = 'Si prega di salvare il documento.';de = 'Bitte speichern Sie das Dokument.'");	
		CommonClientServer.MessageToUser(MessageText);
		
		Return;	
	EndIf;
	
	If Not ValueIsFilled(DocumentForm.Object.Ref) Then
		MessageText = NStr("en = 'Please save the document.'; ru = '???????????????? ?????? ??????????????. ?????????????? ?????????????? ???????????????? ????????????????.';pl = 'Dokument zosta?? zmieniony. Najpierw nale??y zapisa?? dokument.';es_ES = 'Por favor, guardar el documento.';es_CO = 'Por favor, guardar el documento.';tr = 'L??tfen, belgeyi kaydedin.';it = 'Si prega di salvare il documento.';de = 'Bitte speichern Sie das Dokument.'");	
		CommonClientServer.MessageToUser(MessageText);
		
		Return;	
	EndIf;
	
	If Received Then
		FormName = "Document.TaxInvoiceReceived.ObjectForm";
	Else
		FormName = "Document.TaxInvoiceIssued.ObjectForm";
	EndIf;
	
	// Open and enter new document
	ParametersStructureAccountInvoice = New Structure;
	
	If ValueIsFilled(InvoiceFound) Then
		ParametersStructureAccountInvoice.Insert("Key", InvoiceFound.Ref);
	Else
		ParametersStructureAccountInvoice.Insert("Basis", DocumentForm.Object.Ref);
	EndIf;
	
	OpenForm(FormName, ParametersStructureAccountInvoice, DocumentForm);
	
EndProcedure

Procedure ShowReverseChargeNotSupportedMessage(VATTaxation) Export
	
	If VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Debit/credit note issued against invoice with the reverse charge scheme doesn''t impact VAT entries.
			     |If you have any information or clarifications on this case from your tax authority, please, provide them to your vendor.'; 
			     |ru = '??????????????????/???????????????????? ??????????, ???????????????????? ???? ??????????????, ?? ?????????????? ???????????????????????? ?????????????????????? ??????, ???? ???????????? ???? ??????.
			     |???????? ???????? ?????????????????? ???????????? ?????????????????????????? ???????????????????????????? ???????????????????? ?????? ???????????????????????? ???? ???????? ????????????????, ?????????????????? ???? ???????????? ???????????????????? ???????????????????????? ??????????????????????.';
			     |pl = 'Nota debetowa/kredytowa wystawiona na faktur?? w systemie odwrotnego obci????enia nie ma wp??ywu na zg??oszenia VAT.
			     |Je??li masz jakie?? informacje lub wyja??nienia w tej sprawie od swojego organu podatkowego, przeka?? je sprzedawcy.';
			     |es_ES = 'Nota de d??bito/cr??dito emitida contra la factura con el esquema de la inversi??n impositiva no afecta las entradas de diario del IVA.
			     |Si tiene alguna informaci??n o aclaraciones sobre el asunto de su autoridad fiscal, por favor, proporcionarlas a su vendedor.';
			     |es_CO = 'Nota de d??bito/cr??dito emitida contra la factura con el esquema de la inversi??n impositiva no afecta las entradas del IVA.
			     |Si tiene alguna informaci??n o aclaraciones sobre el asunto de su autoridad fiscal, por favor, proporcionarlas a su vendedor.';
			     |tr = 'Kar???? ??demeli ??cret plan??na sahip faturaya kar???? ????kar??lan bor?? / alacak dekontu KDV giri??lerini etkilemez. 
			     | Bu durum hakk??nda vergi dairenizden herhangi bir bilginiz veya a????klaman??z varsa l??tfen sat??c??n??za bildirin.';
			     |it = 'Debito/nota di credito emessa a fronte della fattura, con il regime di ""reverse charge"" non impatto voci di IVA.
			     |se hai qualche informazione o chiarimento in questo caso dalla vostra autorit?? fiscale, si prega di fornire il vostro fornitore.';
			     |de = 'Die gegen Rechnung mit dem Steuerschuldumkehr-Verfahren ausgestellte Lastschrift / Gutschrift hat keine Auswirkungen auf die USt.-Eingabe.
			     |Wenn Sie von Ihrer Steuerbeh??rde Informationen oder Klarstellungen zu diesem Fall haben, geben Sie diese bitte Ihrem Verk??ufer an.'"),
			,
			,
			,
			);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

Procedure SetVisibleOfVATNumbers(Form, SwitchTypeListOfVATNumbers, AttributeName = "Object", UseMultipleVATNumbers = Undefined) Export
	
	If UseMultipleVATNumbers = Undefined Then
		UseMultipleVATNumbers = WorkWithVATServerCall.MultipleVATNumbersAreUsed();
	EndIf;
	
	Form.Items.GroupSingleVATNumber.Visible = Not UseMultipleVATNumbers Or Not SwitchTypeListOfVATNumbers;
	Form.Items.GroupMultipleVATNumbers.Visible = UseMultipleVATNumbers And SwitchTypeListOfVATNumbers;
	
	SetVATNumbersRowFilter(Form, AttributeName);
	
EndProcedure

Procedure SetVATNumbersRowFilter(Form, AttributeName = "Object", CurrentData = Undefined) Export
	
	ShowExpired = Form.Items.VATNumbersShowExpiredVATIDs.Check;
	
	If ShowExpired Then
		Form.Items.VATNumbers.RowFilter = New FixedStructure;
	Else
		
		CurrentDate = BegOfDay(CurrentDate());
		
		If CurrentData = Undefined Then
			
			For Each CurrentData In Form[AttributeName].VATNumbers Do
				CurrentData.Expired = VATNumberIsExpired(CurrentData, CurrentDate);
			EndDo;
			
		Else
			CurrentData.Expired = VATNumberIsExpired(CurrentData, CurrentDate);
		EndIf;
			
		Form.Items.VATNumbers.RowFilter = New FixedStructure(New Structure("Expired", False));	
		
	EndIf;
	
EndProcedure

Function CheckSelectedVATNumber(ListRow, MessageText) Export
	
	If Not ValueIsFilled(ListRow.VATNumber) Then
		
		MessageText = NStr("en = 'VAT ID is required.'; ru = '?????????????????? ?????????? ?????????????????????? ??????.';pl = 'Numer VAT jest wymagany.';es_ES = 'Se requiere el identificador del IVA.';es_CO = 'Se requiere el identificador de IVA.';tr = 'KDV kodu gerekli.';it = 'ID IVA richiesto.';de = 'USt.-IdNr. ist erforderlich.'");
		Return False;
		
	EndIf;
	
	CurrentDate = BegOfDay(CurrentDate());
	EmptyDate = Date(1,1,1);

	If (ListRow.RegistrationDate > CurrentDate And ListRow.RegistrationDate <> EmptyDate)
		Or (ListRow.RegistrationValidTill < CurrentDate And ListRow.RegistrationValidTill <> EmptyDate) Then	
		
		MessageText = NStr("en = 'The validity period of the selected VAT ID has expired. Select another VAT ID.'; ru = '???????? ???????????????? ???????????????????? ???????????? ?????????????????????? ?????? ??????????. ???????????????? ???????????? ?????????? ?????????????????????? ??????.';pl = 'Okres obowi??zywania wybranego numeru VAT wygas??. Wybierz inny numer VAT.';es_ES = 'El per??odo de validez del identificador del IVA seleccionado ha expirado. Seleccione otro identificador del IVA.';es_CO = 'El per??odo de validez del identificador del IVA seleccionado ha expirado. Seleccione otro identificador del IVA.';tr = 'Se??ilen KDV kodunun ge??erlilik s??resi sona erdi. Ba??ka bir KDV kodu se??in.';it = 'Il periodo di validit?? dell''ID IVA selezionata ?? scaduto. Selezionare un''altra ID IVA.';de = 'Der G??ltigkeitszeitraum der ausgew??hlten USt-IdNr. ist abgelaufen. W??hlen Sie eine andere Ust.-IdNr.'");
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

Procedure CheckValidDates(Form, Item, CurrentData, AttributeName = "Object") Export
		
	If ValueIsFilled(CurrentData.RegistrationDate) And ValueIsFilled(CurrentData.RegistrationValidTill) Then
		
		If CurrentData.RegistrationDate > CurrentData.RegistrationValidTill Then
			
			TableName = Item.Parent.Name;
			ColumnName = StrReplace(Item.Name, TableName, "");
			
			CurrentIndex = Form[AttributeName][TableName].IndexOf(CurrentData);
			MessageText = NStr("en = 'The Registration date cannot be later than the Valid till date.'; ru = '???????? ?????????????????????? ???? ?????????? ???????? ???????????? ???????? ???????? ????????????????.';pl = 'Data rejestracji nie mo??e by?? p????niejsza ni?? data wa??no??ci.';es_ES = 'La fecha de registro no puede ser posterior a la fecha de caducidad.';es_CO = 'La fecha de registro no puede ser posterior a la fecha de caducidad.';tr = 'Kay??t tarihi Ge??erlilik sonu tarihinden ileri olamaz.';it = 'La data di registrazione non pu?? essere successiva alla data Valido fino a.';de = 'Das Anmeldedatum darf nicht nach dem ""G??ltig bis""-Datum liegen.'");
			
			CommonClientServer.MessageToUser(
				MessageText, 
				, 
				AttributeName + "." + TableName + "[" + CurrentIndex + "]." + ColumnName);
			
			CurrentData.RegistrationDate = Form.CurrentRegistrationDate;
			CurrentData.RegistrationValidTill = Form.CurrentValidTillDate;
			
			Return;
						
		EndIf;
		
	EndIf;
	
	Form.CurrentRegistrationDate = CurrentData.RegistrationDate;
	Form.CurrentValidTillDate = CurrentData.RegistrationValidTill;
	
	WorkWithVATClient.SetVATNumbersRowFilter(Form, AttributeName, CurrentData);
	
EndProcedure

Function VATNumberIsExpired(CurrentData, CurrentDate)
	
	Return ValueIsFilled(CurrentData.RegistrationDate) And CurrentData.RegistrationDate > CurrentDate
		Or ValueIsFilled(CurrentData.RegistrationValidTill) And CurrentData.RegistrationValidTill < CurrentDate;
	
EndFunction

#EndRegion