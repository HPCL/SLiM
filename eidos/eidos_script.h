//
//  eidos_script.h
//  Eidos
//
//  Created by Ben Haller on 4/1/15.
//  Copyright (c) 2015 Philipp Messer.  All rights reserved.
//	A product of the Messer Lab, http://messerlab.org/software/
//

//	This file is part of Eidos.
//
//	Eidos is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//	Eidos is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License along with Eidos.  If not, see <http://www.gnu.org/licenses/>.

/*
 
 The class EidosScript represents a script written in the Eidos language.  It handles its tokenizing and parsing itself.
 
 */

#ifndef __Eidos__eidos_script__
#define __Eidos__eidos_script__

#include <vector>
#include <string>

#include "eidos_token.h"
#include "eidos_ast_node.h"


class EidosValue;
class EidosFunctionSignature;


// set these to true to get logging of tokens / AST / evaluation
extern bool gEidosLogTokens;
extern bool gEidosLogAST;
extern bool gEidosLogEvaluation;


// A class representing an entire script and all associated tokenization and parsing baggage
class EidosScript
{
	//	This class has its copy constructor and assignment operator disabled, to prevent accidental copying.
	
protected:
	
	const std::string script_string_;		// the full string for the script, from start-brace to the end of the end-brace line
	int start_character_index_;				// the index of the first Eidos-based character in the script string
	
	std::vector<EidosToken *> token_stream_;					// OWNED POINTERS
	EidosASTNode *parse_root_ = nullptr;						// OWNED POINTER
	
	// parsing ivars, valid only during parsing
	int parse_index_;						// index into token_stream_ of the current token
	EidosToken *current_token_;				// token_stream_[parse_index_]; owned indirectly
	EidosTokenType current_token_type_;		// token_stream_[parse_index_]->token_type_
	
public:
	
	EidosScript(const EidosScript&) = delete;								// no copying
	EidosScript& operator=(const EidosScript&) = delete;					// no copying
	EidosScript(void) = delete;												// no null construction
	EidosScript(const std::string &p_script_string, int p_start_index);
	
	virtual ~EidosScript(void);												// destructor
	
	void Tokenize(bool p_keep_nonsignificant = false);			// generate token stream from script string
	void AddOptionalSemicolon(void);							// add a semicolon to unterminated input like "6+7" so it works in the console
	
	void ParseInterpreterBlockToAST(void);						// generate AST from token stream for an interpreter block ( statement* EOF )
	
	void PrintTokens(std::ostream &p_outstream) const;
	void PrintAST(std::ostream &p_outstream) const;
	
	inline const std::vector<EidosToken *> &Tokens(void) const		{ return token_stream_; }
	inline const EidosASTNode *AST(void) const						{ return parse_root_; }
	
	// Parsing methods; see grammar for definitions
	void Consume();
	void SetErrorPositionFromCurrentToken(void);
	void Match(EidosTokenType p_token_type, const char *p_context_cstr);
	
	// Top-level parse method for the Eidos interpreter and other contexts
	EidosASTNode *Parse_InterpreterBlock(void);
	
	// Lower-level parsing
	EidosASTNode *Parse_CompoundStatement(void);
	EidosASTNode *Parse_Statement(void);
	EidosASTNode *Parse_ExprStatement(void);
	EidosASTNode *Parse_SelectionStatement(void);
	EidosASTNode *Parse_DoWhileStatement(void);
	EidosASTNode *Parse_WhileStatement(void);
	EidosASTNode *Parse_ForStatement(void);
	EidosASTNode *Parse_JumpStatement(void);
	EidosASTNode *Parse_Expr(void);
	EidosASTNode *Parse_AssignmentExpr(void);
	EidosASTNode *Parse_LogicalOrExpr(void);
	EidosASTNode *Parse_LogicalAndExpr(void);
	EidosASTNode *Parse_EqualityExpr(void);
	EidosASTNode *Parse_RelationalExpr(void);
	EidosASTNode *Parse_AddExpr(void);
	EidosASTNode *Parse_MultExpr(void);
	EidosASTNode *Parse_SeqExpr(void);
	EidosASTNode *Parse_ExpExpr(void);
	EidosASTNode *Parse_UnaryExpr(void);
	EidosASTNode *Parse_PostfixExpr(void);
	EidosASTNode *Parse_PrimaryExpr(void);
	EidosASTNode *Parse_ArgumentExprList(void);
	EidosASTNode *Parse_Constant(void);
};


#endif /* defined(__Eidos__eidos_script__) */


































































