create database election;
use election;

CREATE TABLE states ( 
    state_id varchar(255) PRIMARY KEY, 
    state_name VARCHAR(255) NOT NULL 
); 
 
 
 
CREATE TABLE partywise_results ( 
    party_id INT PRIMARY KEY, 
    party_name VARCHAR(255) NOT NULL, 
    won INT NOT NULL 
); 
 
 
CREATE TABLE constituencywise_results ( 
    constituency_id VARCHAR(255) PRIMARY KEY, 
    parliament_constituency VARCHAR(255) NOT NULL, 
    constituency_name VARCHAR(255) NOT NULL, 
    winning_candidate VARCHAR(255) NOT NULL, 
    total_votes INT NOT NULL, 
    margin INT NOT NULL, 
    party_id INT, 
    FOREIGN KEY (party_id) REFERENCES 
partywise_results(party_id) 
); 
 
 
 
 
 
CREATE TABLE Candidates ( 
    candidate_id INT PRIMARY KEY AUTO_INCREMENT, 
    candidate_name VARCHAR(255) NOT NULL, 
    party_name VARCHAR(255) NOT NULL, 
    evm_votes INT NOT NULL, 
    postal_votes INT NOT NULL, 
    total_votes INT NOT NULL, 
    vote_percentage DECIMAL(5,2) NOT NULL, 
    constituency_id VARCHAR(255), 
    FOREIGN KEY (constituency_id) REFERENCES 
constituencywise_results(constituency_id) 
); 
 
 
 
 
 
CREATE TABLE statewise_results ( 
    statewise_id INT PRIMARY KEY AUTO_INCREMENT, 
    constituency VARCHAR(255) NOT NULL, 
    constituency_no INT NOT NULL, 
    parliament_constituency VARCHAR(255) NOT NULL, 
    leading_candidate VARCHAR(255) NOT NULL, 
    trailing_candidate VARCHAR(255) NOT NULL, 
    margin INT NOT NULL, 
    status VARCHAR(50) NOT NULL, 
    state_id varchar(255),
    FOREIGN KEY (state_id) REFERENCES states(state_id) 
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/statewise_results.csv'
INTO TABLE election.statewise_results
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(constituency, constituency_no, parliament_constituency, leading_candidate, trailing_candidate, margin, status, state_id, @dummy);


/* 
a. Party Performance Analysis - Find the party with the highest 
number of seats won. 
*/

select p.party_name, p.won
from election.partywise_results p
order by won desc
limit 1;


 
/* b. Winning Margin Analysis - Identify the candidate with the highest 
and lowest winning margin. 
*/

with highest_margin as (
select c1.winning_candidate, c1.margin, c1.constituency_name
from election.constituencywise_results c1
order by c1.margin desc
limit 1
),
lowest_margin as (
select c1.winning_candidate, c1.margin, c1.constituency_name
from election.constituencywise_results c1
where c1.margin >0
order by c1.margin asc
limit 1
)

select 'highest margin' as margin_type, winning_candidate, margin, constituency_name from highest_margin
union all
select 'lowest margin' as margin_type, winning_candidate, margin, constituency_name from lowest_margin;
 
/* c. Total Votes by Party - Calculate the total votes received by each 
party across all constituencies. 
*/

select p1.party_id, p1.party_name, 
sum(c1.total_votes) as total_votes
from election.constituencywise_results c1
inner join election.partywise_results p1
on p1.party_id = c1.party_id
group by p1.party_id, p1.party_name
order by total_votes desc;

/* 
d. Closest Contest Analysis - Find the constituency with the smallest 
winning margin. 
*/

select c1.winning_candidate, c1.constituency_name, c1.margin
from election.constituencywise_results c1
where c1.total_votes > 0
and margin >0
order by c1.margin asc
limit 1;


/* 
e. Statewise Voter Turnout - Determine the state with the highest 
and lowest voter turnout. 
*/


with total_vote as (
select sr1.state_id, s1.state_name, sum(cr1.total_votes) as total_votes 
from election.states s1
inner join election.statewise_results sr1
on sr1.state_id = s1.state_id
inner join election.constituencywise_results cr1
on sr1.constituency = cr1.constituency_name
group by sr1.state_id, s1.state_name
),
rank_state as (
select *, 
rank() over(order by total_votes desc) as rank_desc,
rank() over(order by total_votes asc) as rank_asc
from total_vote
)

select 'Highest Voter Turnout' as turnout_type, state_name, total_votes
from rank_state
where rank_desc = 1
union all
select 'Lowest Voter Turnout' as turnout_type, state_name, total_votes
from rank_state
where rank_asc = 1;



/* 
f. Winning Percentage Calculation - Calculate the percentage of 
votes secured by the winning candidate in each constituency. 
 */
 
with total_votes_per_constituency as (
select constituency_id, SUM(total_votes) AS total_votes_in_constituency
from election.Candidates
group by constituency_id
),
winning_candidates as (
select 
	c.constituency_id,
	c.candidate_name,
	c.total_votes as votes_secured
    from election.Candidates c
    inner join election.constituencywise_results cr 
	on c.constituency_id = cr.constituency_id
    where c.candidate_name = cr.winning_candidate
)

select 
    wc.constituency_id,
    wc.candidate_name as winning_candidate,
    wc.votes_secured,
    tv.total_votes_in_constituency,
    round(wc.votes_secured * 100.0 / tv.total_votes_in_constituency, 2) as winning_percentage
from winning_candidates wc
join total_votes_per_constituency tv 
on wc.constituency_id = tv.constituency_id;




 
 /*
g. Majority Constituencies - Find the number of constituencies 
where the winning candidate received more than 50% of total 
votes. 
*/

with total_votes_per_constituency as (
select constituency_id, SUM(total_votes) AS total_votes_in_constituency
from election.Candidates
group by constituency_id
),
winning_candidates as (
select 
	c.constituency_id,
	c.candidate_name,
	c.total_votes as votes_secured
    from election.Candidates c
    inner join election.constituencywise_results cr 
	on c.constituency_id = cr.constituency_id
    where c.candidate_name = cr.winning_candidate
)

select count(*) as majority_constituencies
from winning_candidates wc
join total_votes_per_constituency tv 
on wc.constituency_id = tv.constituency_id
where wc.votes_secured > 0.5 * tv.total_votes_in_constituency;

/* 
h. Runner-Up Party Analysis - Identify the party that secured the 
most runner-up positions. 
 */
 
with rank_position as (
    select candidate_name, party_name, total_votes, constituency_id,
	rank () over (partition by constituency_id order by total_votes desc) as position_rank
    from election.candidates
)
 select party_name, count(*) as runner_up_count
from rank_position
where position_rank = 2
group by party_name
order by runner_up_count desc
limit 1;


 
 /*
i. Independent Candidates' Performance - Find the number of 
independent candidates who won and their constituencies. 
 */
 
 select count(*) as total_independent_candidates
 from election.candidates c
 inner join election.constituencywise_results cr
 on cr.constituency_id = c.constituency_id
 where c.party_name = 'Independent'
 and c.candidate_name = cr.winning_candidate;
 

 select c.candidate_name, cr.constituency_name
 from election.candidates c
 inner join election.constituencywise_results cr
 on cr.constituency_id = c.constituency_id
 where c.party_name = 'Independent'
 and c.candidate_name = cr.winning_candidate;
 
 /*
j. Margin of Victory Trends - Calculate the average margin of 
victory across all constituencies.
*/

select 
round(avg(cr.margin), 2) as average_margin_of_victory
from election.constituencywise_results cr;



