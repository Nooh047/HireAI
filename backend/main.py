from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from typing import List
import shutil
import pdfplumber
import os
import re
import PyPDF2
import spacy
from pathlib import Path
import fitz  # PyMuPDF library for handling PDFs
from thefuzz import fuzz  # Library for fuzzy string matching
import datetime

# Initialize FastAPI app
app = FastAPI()

# Enable CORS to allow frontend applications to communicate with the backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows requests from all origins
    allow_credentials=True,  # Allows cookies and authentication headers to be included in cross-origin requests
    allow_methods=["*"],  # Allows all HTTP methods (GET, POST, PUT, DELETE, etc.)
    allow_headers=["*"],  # Allows all headers
)


# Define the database URL (using SQLite in this case)
DATABASE_URL = "sqlite:///./resumes.db"

# Create a base class for defining database models
Base = declarative_base()

# Create a database engine to manage SQLite connections
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

# Create a session factory to interact with the database
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Define the directory where uploaded resumes will be stored
UPLOAD_DIR = "uploaded_resumes"
os.makedirs(UPLOAD_DIR, exist_ok=True)  # Create the directory if it does not exist

# Define a database model for storing resume details
class Resume(Base):
    __tablename__ = "resumes"  # Name of the database table

    id = Column(Integer, primary_key=True, index=True)  # Unique ID for each resume
    name = Column(String)  # Candidate's name
    phone = Column(String)  # Contact number
    email = Column(String)  # Email address
    qualification = Column(String)  # Candidate's highest qualification
    skills = Column(String)  # Extracted skills from the resume
    experience = Column(Integer)  # Years of work experience
    file_path = Column(String)  # Path to the uploaded resume file
    score = Column(Float, default=0.0)  # Score assigned after analysis

# Create the database tables based on the defined models
Base.metadata.create_all(bind=engine)


# Dependency to get the database session
def get_db():
    db = SessionLocal()  # Create a new database session
    try:
        yield db  # Provide the session to the request
    finally:
        db.close()  # Ensure the session is closed after use

# Define a Pydantic model for filtering criteria
class Criteria(BaseModel):
    qualification: str  # Required qualification (e.g., "B.Tech", "MBA")
    skills: str  # Required skills (comma-separated string)
    experience: int  # Minimum required years of experience
    resumes_selected: int  # Number of resumes to be shortlisted

# Load the English NLP model from spaCy for text processing
nlp = spacy.load("en_core_web_sm")
# Define a regex pattern to extract qualifications from resumes
QUALIFICATION_PATTERN = re.compile(
    r'\b('
    r'Bachelor|Master|Doctorate|PhD|Diploma|Associate|Certification|'
    r'B\.?Tech|M\.?Tech|B\.?E|M\.?E|B\.?Sc|M\.?Sc|BCA|MCA|BBA|MBA|PGDM|PG Diploma|'
    r'B\.?Com|M\.?Com|B\.?A|M\.?A|BFA|MFA|BMS|'
    r'B\.?Pharm|M\.?Pharm|D\.?Pharm|Pharm\.?D|'
    r'B\.?Ed|M\.?Ed|D\.?Ed|'
    r'LLB|LLM|JD|'
    r'CA|CPA|CS|ICWA|CFA|CMA|CFP|ACCA|CISA|'
    r'BDS|MDS|MBBS|MD|MS|BHMS|BAMS|BUMS|BVSc|MVSc|BPT|MPT|'
    r'B\.?Arch|M\.?Arch|'
    r'GNIIT|NIIT Certification|CCNA|CCNP|CCIE|AWS Certified|Azure Certified|Google Cloud Certified|PMP|Six Sigma|'
    r'SSLC|Plus Two|Higher Secondary|High School|Secondary School|Intermediate|10th|12th|HSC|SSC|IGCSE|GCSE|IB Diploma|A Levels|O Levels|'
    r'Polytechnic|ITI|Vocational Diploma|'
    r'RN|BSN|MSN|CNA|'
    r'Chartered Engineer|Professional Engineer|'
    r'Executive MBA|Online MBA|'
    r'MPH|MHA|'
    r'PG Certificate|Graduate Certificate|Advanced Diploma|'
    r'Artificial Intelligence Certification|Data Science Certification|Digital Marketing Certification|'
    r'Cybersecurity Certification|Blockchain Certification|'
    r'Film Making Diploma|Photography Diploma|Animation Diploma|'
    r'Fashion Designing|Interior Designing|'
    r'Event Management Diploma|Hotel Management Diploma|'
    r'Fire and Safety Diploma|'
    r'Environment Management Certification|'
    r'Automotive Engineering|Aerospace Engineering|Marine Engineering|'
    r'Industrial Training|Technical Certification|'
    r'Cloud Computing Diploma|Machine Learning Certification|AI Certification|'
    r'Graphic Design Certification|UI/UX Certification|Web Development Certification|'
    r'Full Stack Development Certification|DevOps Certification|Data Analytics Certification|Business Analytics Certification|'
    r'Foreign Language Diploma|TEFL|TESOL|'
    r'Food Technology Diploma|Agriculture Diploma|'
    r'Journalism Diploma|Mass Communication Diploma|'
    r'Supply Chain Management Certification|Logistics Certification|'
    r'Entrepreneurship Certification|'
    r'Public Relations Certification|'
    r'Forex Certification|Investment Banking Certification|Stock Market Certification|'
    r'Clinical Research Certification|Phlebotomy Certification|'
    r'Legal Assistant Certification|Paralegal Certification|'
    r'Occupational Therapy Certification|Speech Therapy Certification|'
    r'Counseling Certification|'
    r'Yoga Certification|Fitness Trainer Certification|Sports Management Diploma|'
    r'Artificial Intelligence Diploma|Big Data Certification|'
    r'Electrical Engineering|Civil Engineering|Mechanical Engineering|'
    r'Biomedical Engineering|Biotechnology Engineering|Chemical Engineering|'
    r'Nursing Diploma|Healthcare Management Diploma|'
    r'Law Enforcement Diploma|Criminal Justice Diploma|'
    r'Psychology Diploma|Sociology Diploma|Philosophy Diploma|'
    r'Library Science Diploma|'
    r'Statistics Certification|Mathematics Diploma|'
    r'Tourism and Hospitality Diploma|'
    r'Culinary Arts Diploma|'
    r'Software Testing Certification|Penetration Testing Certification|Ethical Hacking Certification|'
    r'UI/UX Design Diploma|Game Development Diploma|'
    r'Sound Engineering Diploma|Music Production Diploma|'
    r'Agribusiness Diploma|'
    r'Nanotechnology Diploma|Geology Diploma|'
    r'Actuarial Science Certification|Risk Management Certification|'
    r'Child Development Certification|Social Work Diploma|'
    r'Corporate Law Certification|'
    r'Veterinary Science Diploma|'
    r'Environmental Science Diploma|'
    r'Renewable Energy Diploma|Solar Energy Certification|Wind Energy Certification|'
    r'Construction Management Diploma|Real Estate Management Diploma|'
    r'Aviation Management Diploma|Pilot Training Certification|Cabin Crew Training Certification|'
    
    # Added Comprehensive Bachelor Degrees
    r'Bachelor of Arts|Bachelor of Science|Bachelor of Commerce|Bachelor of Business Administration|Bachelor of Computer Applications|'
    r'Bachelor of Engineering|Bachelor of Technology|Bachelor of Architecture|Bachelor of Fine Arts|'
    r'Bachelor of Pharmacy|Bachelor of Education|Bachelor of Laws|Bachelor of Dental Surgery|'
    r'Bachelor of Medicine|Bachelor of Surgery|Bachelor of Physiotherapy|Bachelor of Occupational Therapy|'
    r'Bachelor of Veterinary Science|Bachelor of Social Work|Bachelor of Hospitality Management|'
    r'Bachelor of Hotel Management|Bachelor of Tourism and Travel Management|'
    r'Bachelor of Journalism and Mass Communication|Bachelor of Performing Arts|Bachelor of Visual Arts|'
    r'Bachelor of Ayurvedic Medicine and Surgery|Bachelor of Homeopathic Medicine and Surgery|'
    r'Bachelor of Unani Medicine and Surgery|Bachelor of Business Studies|Bachelor of Management Studies|'
    r'Bachelor of International Business|Bachelor of Financial Services|'
    r'Bachelor of Computer Science|Bachelor of Information Technology|Bachelor of Data Science|'
    r'Bachelor of Cybersecurity|Bachelor of Cloud Computing|Bachelor of Artificial Intelligence|'
    r'Bachelor of Machine Learning|Bachelor of Digital Marketing|Bachelor of Event Management|'
    r'Bachelor of Fashion Design|Bachelor of Interior Design|Bachelor of Product Design|'
    r'Bachelor of Animation|Bachelor of Multimedia|Bachelor of Film Making|'
    r'Bachelor of Sports Management|Bachelor of Physical Education|Bachelor of Fitness Management|'
    r'Bachelor of Agriculture|Bachelor of Forestry|Bachelor of Fisheries Science|'
    r'Bachelor of Biotechnology|Bachelor of Environmental Science|'
    r'Bachelor of Industrial Design|Bachelor of Marine Engineering|Bachelor of Naval Architecture|'
    r'Bachelor of Aviation|Bachelor of Aircraft Maintenance Engineering|'
    r'Bachelor of Economics|Bachelor of Statistics|Bachelor of Mathematics|'
    r'Bachelor of Political Science|Bachelor of Philosophy|Bachelor of Sociology|Bachelor of Psychology|'
    r'Bachelor of Anthropology|Bachelor of History|Bachelor of Public Administration|'
    r'Bachelor of Criminology|Bachelor of Forensic Science'
    r')\b',
    re.IGNORECASE
)


SKILL_DICTIONARY = [
    # Programming Languages
    "Python", "Java", "Flutter", "SQL", "Django", "FastAPI", "JavaScript", "TypeScript",  
    "C#", "C++", "Go", "Rust", "Ruby", "Kotlin", "Swift", "PHP", "R", "Perl",  

    # Databases & Backend Technologies
    "MongoDB", "MySQL", "PostgreSQL", "SQLite", "Redis", "GraphQL", "Firebase", "OracleDB",  

    # Web Development
    "HTML", "CSS", "React", "Vue.js", "Angular", "Node.js", "Next.js", "Nuxt.js",  
    "Express.js", "Svelte", "ASP.NET", "Laravel", "Spring Boot",  

    # Mobile Development
    "React Native", "SwiftUI", "Jetpack Compose", "Ionic", "Xamarin",  

    # Cloud & DevOps
    "AWS", "Azure", "Google Cloud", "Kubernetes", "Docker", "Terraform", "Jenkins",  
    "Ansible", "GitHub Actions", "CI/CD", "Linux Administration",  

    # Data Science & Machine Learning
    "Pandas", "NumPy", "Scikit-learn", "TensorFlow", "PyTorch", "Keras",  
    "Matplotlib", "Seaborn", "Hugging Face", "NLP", "Computer Vision",  

    # Cybersecurity
    "Penetration Testing", "Ethical Hacking", "Network Security", "Cloud Security",  
    "Cryptography", "SOC Analysis",  

    # Business & Soft Skills
    "Recruitment", "Payroll", "Employee Relations", "Compliance Management",  
    "SEO", "Digital Marketing", "Social Media", "Content Marketing",  
    "Communication", "Leadership", "Problem Solving", "Team Management",  

    # Marketing & Design
    "Adobe Photoshop", "Adobe Illustrator", "Canva", "UI/UX Design",  
    "Wireframing", "Figma", "Sketch",  

    # Others
    "Agile Methodologies", "Scrum", "Project Management", "Business Analysis",  
    "Customer Relationship Management (CRM)", "Blockchain", "IoT",  
]

# Define a regex pattern to extract job titles from resumes
JOB_TITLE_PATTERN = re.compile(
    r"(Software Engineer|Data Scientist|Machine Learning Engineer|Project Manager|"
    r"DevOps Engineer|Web Developer|Frontend Developer|Backend Developer|Full Stack Developer|"
    r"Business Analyst|Product Manager|System Administrator|Network Engineer|Cyber Security Analyst|"
    r"AI Engineer|Cloud Engineer|Technical Lead|Software Architect|QA Engineer|Data Analyst|Supervisor)",
    re.IGNORECASE  # Make the pattern case-insensitive
)


try:
    # Attempt to load the pre-trained English NLP model from spaCy
    nlp = spacy.load("en_core_web_sm")
except:
    # If the model is not found, download it dynamically
    import subprocess
    subprocess.run(["python", "-m", "spacy", "download", "en_core_web_sm"])

    # Load the model again after installation
    nlp = spacy.load("en_core_web_sm")


def extract_text_from_pdf(pdf_path):
    """
    Extract text from a PDF using PyMuPDF (more reliable than PyPDF2 for text extraction)
    Falls back to PyPDF2 if PyMuPDF fails
    """
    text = ""
    
    # Try PyMuPDF first (generally better text extraction)
    try:
        with fitz.open(pdf_path) as pdf:# Open PDF file with PyMuPDF
            for page_num in range(len(pdf)):# Loop through all pages
                page = pdf[page_num]# Access each page
                text += page.get_text()# Extract text from each page
    except Exception as e:
        print(f"PyMuPDF extraction failed, trying PyPDF2: {e}")# Log error if PyMuPDF fails
        
        # Fall back to PyPDF2
        try:
            with open(pdf_path, 'rb') as file: # Open PDF file in binary mode
                reader = PyPDF2.PdfReader(file)# Create a PyPDF2 reader object
                for page_num in range(len(reader.pages)):# Loop through all pages
                    text += reader.pages[page_num].extract_text() + "\n" # Extract text from each page
        except Exception as e2:
            print(f"PyPDF2 extraction also failed: {e2}") # Log error if PyPDF2 also fails
    
    return text# Return extracted text

def extract_text_from_pdf(pdf_path):
    """
    Extract text from a PDF using PyPDF2
    """
    text = ""# Initialize an empty string to store extracted text
    try:
        with open(pdf_path, 'rb') as file:# Open the PDF file in binary mode
            reader = PyPDF2.PdfReader(file) # Create a PyPDF2 reader object
            # Loop through all pages and extract text
            for page_num in range(len(reader.pages)):
                text += reader.pages[page_num].extract_text() + "\n" # Extract text from each page
    except Exception as e:
        print(f"PDF extraction failed: {e}") # Print an error message if extraction fails
    
    return text # Return the extracted text

def extract_name(text):
    """
    Extract candidate name from text using multiple methods,
    with improved handling for different resume layouts
    """
    if not text or len(text.strip()) == 0: # If text extraction fails
        return "Text extraction failed"
    
    lines = text.split("\n")# Split the extracted text into lines using newline as a separator
    cleaned_lines = [line.strip() for line in lines if line.strip()]# Remove leading/trailing spaces from each line and filter out empty lines
    
    # Store potential name candidates with their scores
    name_candidates = []
    
    # 1. Check for isolated text blocks at the top - often the name
    # Names are frequently the most prominent text at the top of the resume
    top_lines = cleaned_lines[:7]  # Examine more top lines
    for i, line in enumerate(top_lines):
        line = line.strip()
        if 2 <= len(line.split()) <= 4 and len(line) < 40:
            words = line.split()
            non_name_indicators = ["resume", "cv", "curriculum", "vitae", "profile", "application", 
                                   "address", "phone", "email", "github", "linkedin"]
            
            if (all(word[0].isupper() for word in words if word) and 
                not any(indicator in line.lower() for indicator in non_name_indicators)):
                # Higher score for lines at the very top
                score = 100 - (i * 10)
                name_candidates.append((line, score, "top_isolated"))
    
    # 2. Header-based detection for names
    name_headers = ["Name", "Full Name", "Candidate Name", "Profile", "Personal Information", "Personal Details"]
    
    for i, line in enumerate(cleaned_lines[:25]):  # Check more lines
        # Check for common patterns like "Name: John Doe" or "Name - John Doe"
        for header in name_headers:
            if header.lower() in line.lower():
                for separator in [":", "-", "–", ">"]:  # Check various separators
                    if separator in line:
                        parts = line.split(separator)
                        if len(parts) >= 2:
                            name_candidate = parts[1].strip()
                            if 2 <= len(name_candidate.split()) <= 5 and all(len(word) > 1 for word in name_candidate.split()):
                                score = 90
                                name_candidates.append((name_candidate, score, "header_based"))
    
    # 3. Look for left-aligned or right-aligned name patterns
    # This helps with two-column resumes or stylized layouts
    left_aligned_pattern = re.compile(r'^([A-Z][a-z]+(?:\s(?:[A-Z]\.?|[A-Z][a-z]+)){1,3})(?:\s*\n|\s{3,})')
    right_aligned_pattern = re.compile(r'(?:\n\s*|\s{3,})([A-Z][a-z]+(?:\s(?:[A-Z]\.?|[A-Z][a-z]+)){1,3})$')
    
    combined_text = "\n".join(cleaned_lines[:15])
    
    # Check for left-aligned names
    left_matches = left_aligned_pattern.findall(combined_text)
    for match in left_matches:
        if 2 <= len(match.split()) <= 4 and not any(word.lower() in ["resume", "cv"] for word in match.split()):
            score = 80
            name_candidates.append((match, score, "left_aligned"))
    
    # Check for right-aligned names
    right_matches = right_aligned_pattern.findall(combined_text)
    for match in right_matches:
        if 2 <= len(match.split()) <= 4 and not any(word.lower() in ["resume", "cv"] for word in match.split()):
            score = 80
            name_candidates.append((match, score, "right_aligned"))
    
    # 4. Improved regex for capitalized names with various formats
    # This catches names in different positions within the text
    name_pattern = re.compile(r'\b([A-Z][a-z]+(?:\s+(?:[A-Z]\.?|[A-Z][a-z]+)){1,4})\b')
    
    for i, line in enumerate(cleaned_lines[:20]):
        matches = name_pattern.findall(line.strip())
        for match in matches:
            if 2 <= len(match.split()) <= 5:
                # Higher score for matches near the top
                score = 70 - (i * 2)
                name_candidates.append((match, score, "regex"))
    
    # 5. NER for person detection
    first_section = " ".join(cleaned_lines[:35])
    doc = nlp(first_section)
    
    for i, ent in enumerate(doc.ents):
        if ent.label_ == "PERSON":
            # Higher score for earlier mentions
            score = 60 - (i * 5)
            if 2 <= len(ent.text.split()) <= 5:
                name_candidates.append((ent.text, score, "ner"))
    
    # 6. Look for patterns like "Resume of John Doe" or "CV of John Doe"
    resume_of_pattern = re.compile(r'(?:resume|cv|curriculum vitae)\s+(?:of|for|by)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,3})', re.IGNORECASE)
    combined_text = " ".join(cleaned_lines[:15])
    resume_of_matches = resume_of_pattern.findall(combined_text)
    
    for match in resume_of_matches:
        if 2 <= len(match.split()) <= 4 and all(word[0].isupper() for word in match.split()):
            score = 85
            name_candidates.append((match, score, "resume_of"))
    
    # 7. Email-based detection as fallback
    email_pattern = re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b')
    for line in cleaned_lines[:30]:
        email_match = email_pattern.search(line)
        if email_match:
            email = email_match.group(0)
            username = email.split('@')[0]
            
            # Try to convert username to a name (e.g., john.doe → John Doe)
            if '.' in username:
                name_parts = username.split('.')
                candidate = ' '.join(part.capitalize() for part in name_parts)
                name_candidates.append((candidate, 30, "email"))
    
    # Sort candidates by score and return the best one
    if name_candidates:
        # Sort by score (descending)
        name_candidates.sort(key=lambda x: x[1], reverse=True)
        
        # Return the highest scoring candidate
        best_name, score, method = name_candidates[0]
        return best_name
    
    return "Name not found"

def extract_name_from_pdf(pdf_path):
    """
    Extract candidate name from a PDF file
    """
    text = extract_text_from_pdf(pdf_path)# Extract text from the given PDF file
    return extract_name(text)# Call extract_name function to identify and return the candidate's name
def extract_name_from_pdf(pdf_path):
    """
    Extract candidate name from a PDF file
    """
    text = extract_text_from_pdf(pdf_path)
    return extract_name(text)

def extract_qualifications(text):
    found_qualifications = set() # Use a set to store unique qualifications
    for qualification in QUALIFICATION_PATTERN.findall(text):# Search for qualifications using the regex pattern
        found_qualifications.add(qualification)# Add each found qualification to the set
    return list(found_qualifications)# Convert the set to a list and return

def extract_skills(text):
    found_skills = set() # Use a set to store unique skills
     # Loop through predefined skills and check if they appear in the text
    for skill in SKILL_DICTIONARY:
        if re.search(rf'\b{re.escape(skill)}\b', text, re.IGNORECASE):
             # \b ensures the skill is a standalone word (not part of another word)
            # re.escape(skill) prevents errors if skill contains special regex characters
            found_skills.add(skill)
    return list(found_skills)  # Convert the set to a list and return

def extract_job_titles(text):
    return list(set(JOB_TITLE_PATTERN.findall(text)))  # Extract and return unique job titles

import re# Import regex module for pattern matching
import datetime # Import datetime module for handling date calculations

def extract_experience(text):
    """
    Extracts total years of experience from resume text.
    Handles:
    - Explicit mentions like "5 years of experience"
    - Date ranges (e.g., "2018 - 2022", "Jan 2018 - Present")
    - Both year-only and month-year formats
    Returns: Total years of experience (integer).
    """
    exp_years = 0 # Initialize experience count to zero (default value)

    # 1. Direct "years of experience" extraction
    # Use regex to find experience patterns like "5 years of experience", "3 yrs experience", etc.
    exp_match = re.search(r'(\d+)\s*(?:years?|yrs?)\s*(?:of\s+)?experience', text, re.IGNORECASE)
    if exp_match:
        exp_years += int(exp_match.group(1)) # Add extracted experience years to the total count

    # 2. Date range extraction (year or month-year ranges)
    date_ranges = re.findall(
        r'(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+)?(\d{4})\s*[-–to]+\s*(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+)?(\d{4}|Present|Current)',
        text,
        re.IGNORECASE
    )

    # 3. Calculate experience from date ranges
    current_year = datetime.datetime.now().year# Get the current year to handle cases where end year is "Present" or "Current"
    for start_year, end_year in date_ranges:# Loop through extracted date ranges (e.g., "2015 - 2020", "Jan 2018 - Present")
        try:
             # Convert the start year to an integer
            start_year = int(start_year)
            # Handle cases where the end year is "Present" or "Current"
            if end_year.lower() in ["present", "current"]:
                end_year = current_year # Set end year to the current year
            else:
                end_year = int(end_year) # Set end year to the current year
                # Ensure the date range is valid (end year should not be before the start year)
            if end_year >= start_year:
                exp_years += (end_year - start_year) # Calculate and add the experience years
        except ValueError:
            continue# Skip invalid date values (e.g., non-numeric years)
# Return the total experience years calculated from date ranges
    return exp_years

def extract_entities(file_path):
    # Switch from PyPDF2 to pdfplumber for better text extraction
    with pdfplumber.open(file_path) as pdf:# Extract text from PDF using pdfplumber (handles complex layouts better than PyPDF2)
        text = "\n".join(page.extract_text() or "" for page in pdf.pages)
 # Extract candidate name using NLP-based function
    name = extract_name(text)

   # Extract phone number using regex (expects a 10-digit number)
    phone = re.search(r'\b\d{10}\b', text)
    phone = phone.group() if phone else "Not Found"  # Assign extracted value or default


   # Extract email using regex pattern
    email = re.search(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', text)
    email = email.group() if email else "Not Found"
     # Extract experience (years) using a predefined function
    experience = extract_experience(text)

    # Extract qualifications using regex or NLP
    qualifications = extract_qualifications(text)
    qualification = ", ".join(qualifications) if qualifications else "Not Found"

     # Extract skills using a predefined function
    skills = extract_skills(text)
   # Extract job titles using regex-based or NLP-based function
    job_titles = extract_job_titles(text)
     # Combine extracted job titles with skills for better matching
    skills += job_titles

    # Return extracted information as a dictionary
    return {
        "name": name,
        "phone": phone,
        "email": email,
        "qualification": qualification,
        "skills": ",".join(skills),  # Convert skill list to a comma-separated string
        "experience": experience
    }

@app.post("/upload/") # Accept multiple file uploads
async def upload_resumes(files: List[UploadFile] = File(...), db: Session = Depends(get_db)):# Get database session
    for file in files: # Construct file path in the upload directory
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_path, "wb") as buffer: # Save the uploaded file to disk
            shutil.copyfileobj(file.file, buffer)# Copy file content to local storage
# Extract structured information from the uploaded resume
        extracted = extract_entities(file_path)
         # Create a new Resume record with extracted details
        resume = Resume(
            name=extracted["name"],  # Extracted candidate name
            phone=extracted["phone"],  # Extracted phone number
            email=extracted["email"],  # Extracted email
            qualification=extracted["qualification"],  # Extracted qualification
            skills=extracted["skills"],  # Extracted skills
            experience=extracted["experience"],  # Extracted experience
            file_path=file_path  # Store file path for reference
        )

        # Add resume record to the database
        db.add(resume)

    # Commit all added resumes to save them in the database
    db.commit()
    return {"message": "Resumes uploaded and processed successfully"}
from thefuzz import fuzz

def calculate_score(candidate, criteria):
    score = 0# Initialize total score

    # Qualification Matching (Fuzzy Match)
    candidate_qualification = candidate.qualification.lower()# Convert qualifications to lowercase for case-insensitive matching
    criteria_qualification = criteria.qualification.lower()
# Calculate similarity between candidate's qualification and required qualification
    qualification_similarity = fuzz.partial_ratio(candidate_qualification, criteria_qualification)
# Assign scores based on similarity level
    if qualification_similarity >= 90:   # Very close match (almost identical)
        score += 30
    elif qualification_similarity >= 70:   # Partial match (some differences but relevant
        score += 15
    else:
        score += 0# No match, no points awarded

    # Skills Matching (Fuzzy Match per skill)
    # Convert candidate's and required skills into lowercase and remove extra spaces
    candidate_skills = [skill.strip().lower() for skill in candidate.skills.split(",")]
    required_skills = [skill.strip().lower() for skill in criteria.skills.split(",")]

# Initialize a counter for matched skills
    matched_skills = 0
    # Compare each required skill with the candidate's skills
    for required_skill in required_skills:
        for candidate_skill in candidate_skills:
            # Calculate similarity score between candidate skill and required skill using fuzzy matching
            skill_similarity = fuzz.ratio(candidate_skill, required_skill)
            if skill_similarity >= 85:  # A similarity of 85% or more is considered a match
                matched_skills += 1# Increase match count
                break# Stop checking other skills once a match is found

# Calculate skill score: 
# - If all required skills are matched, the candidate gets the full 40 points.
# - If only some are matched, the score is proportional to the number of matches.
    skill_score = (matched_skills / max(len(required_skills), 1)) * 40
    # Add skill score to total score
    score += skill_score

    # Experience Matching (Modified to handle 4+ years)
    # Check if the candidate meets or exceeds the required experience
    if candidate.experience >= criteria.experience:
        experience_score = 30 # Full points if the experience meets or exceeds the requirement
    else:
         # Calculate experience gap (difference between candidate's experience and required experience)
        experience_gap = abs(candidate.experience - criteria.experience)
        if experience_gap <= 5:
            experience_score = 30 * (1 - (experience_gap / 5))
        else:
            experience_score = 0# No points if the gap is more than 5 years
# Add the calculated experience score to the total score
    score += experience_score
# Return the final rounded score (up to 2 decimal places for precision)
    return round(score, 2)

@app.post("/rank/")
def rank_resumes(criteria: Criteria, db: Session = Depends(get_db)):
    # Retrieve all resumes from the database
    candidates = db.query(Resume).all()
 # Calculate scores for each candidate based on the given criteria
    for candidate in candidates:
        candidate.score = calculate_score(candidate, criteria)# Assign score
 # Bulk update scores in the database for efficiency
    db.bulk_save_objects(candidates)
    db.commit() # Commit changes to persist updated scores
# Sort candidates by score in descending order (higher scores first)
    ranked = sorted(candidates, key=lambda x: x.score, reverse=True)
     # Return only the top `criteria.resumes_selected` candidates
    return [
        {"id": c.id, "name": c.name, "phone": c.phone, "email": c.email, "score": c.score}
        for c in ranked[:criteria.resumes_selected]
    ]

@app.get("/resume/{resume_id}")
def get_resume(resume_id: int, db: Session = Depends(get_db)):
    # Query the database to find the resume with the given ID
    resume = db.query(Resume).filter(Resume.id == resume_id).first()
    # If no matching resume is found, return a 404 Not Found error
    if not resume:
        raise HTTPException(status_code=404, detail="Resume not found")
    # Return the resume file using FileResponse
    return FileResponse(path=resume.file_path, filename=os.path.basename(resume.file_path)) # The actual file path of the resume
# Set filename for download

@app.delete("/cleanup/")
def cleanup_resumes():

    # Loop through all files in the upload directory
    for file_name in os.listdir(UPLOAD_DIR):
        file_path = os.path.join(UPLOAD_DIR, file_name) # Construct full file path
        os.remove(file_path)# Delete the file
    return {"message": "All uploaded resumes have been cleaned up"} # Return success message

@app.delete("/reset/")
def reset_database(db: Session = Depends(get_db)):
    try:
        # Loop through all files in the upload directory and delete them
        for file_name in os.listdir(UPLOAD_DIR):
            os.remove(os.path.join(UPLOAD_DIR, file_name))  # Remove each file

        # Delete all entries in the Resume table
        db.query(Resume).delete()
        db.commit()  # Commit changes to apply deletion
        return {"message": "Database and uploaded files have been reset successfully"}
    except Exception as e:
        # If an error occurs, return a 500 Internal Server Error with details
        raise HTTPException(status_code=500, detail=f"Error while resetting database: {e}")


@app.get("/resume/{resume_id}")
async def get_resume(resume_id: int, db=SessionLocal()):
    # Fetch the resume record
    resume = db.query(Resume).filter(Resume.id == resume_id).first()
    if not resume or not os.path.exists(resume.file_path):
        raise HTTPException(status_code=404, detail="Resume not found")
    # Serve the resume file
    return FileResponse(resume.file_path, media_type="application/pdf", filename=f"resume_{resume_id}.pdf")

if __name__ == "__main__":
    import uvicorn# Import Uvicorn ASGI server
    # Run the FastAPI app using Uvicorn
    uvicorn.run(app, host="127.0.0.1", port=5000, reload=True)  # FastAPI app instance
    # Allows access from any network (use "127.0.0.1" for local only)
    # Runs the app on port 5000
    # Enables auto-reloading for development (restarts the server on code changes)
